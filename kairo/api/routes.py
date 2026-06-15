"""Kairo HTTP API — driver identity, signed telemetry, contribution dashboard."""

from __future__ import annotations

import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse

from kairo.services.earnings import estimate_rewards
from kairo.services.identity import DriverStore, generate_driver_identity
from kairo.services.mandelbrot_pipeline import MandelbrotPipeline
from kairo.services.signing import sign_telemetry, verify_telemetry
from kairo.models.driver import SignedTelemetry


class KairoApi:
    def __init__(self) -> None:
        self.drivers = DriverStore()
        self.pipeline = MandelbrotPipeline()

    def create_driver(self, body: dict[str, Any]) -> dict[str, Any]:
        driver_id = body.get("driver_id")
        identity = generate_driver_identity(driver_id)
        self.drivers.save(identity)
        return identity.to_public_dict()

    def get_driver(self, driver_id: str) -> dict[str, Any]:
        identity = self.drivers.get(driver_id)
        if not identity:
            raise KeyError("driver not found")
        return identity.to_public_dict()

    def submit_telemetry(self, body: dict[str, Any]) -> dict[str, Any]:
        driver_id = body["driver_id"]
        payload = body["payload"]
        identity = self.drivers.get(driver_id)
        if not identity:
            raise KeyError("driver not found")

        if "signature" in body:
            packet = SignedTelemetry(
                driver_id=driver_id,
                evm_address=identity.evm_address,
                payload=payload,
                signature=body["signature"],
                signed_at=body.get("signed_at", ""),
            )
            if not verify_telemetry(packet, identity.public_key_hex):
                raise ValueError("invalid telemetry signature")
        else:
            packet = sign_telemetry(identity, payload)

        record = self.pipeline.ingest(packet)
        return {"accepted": True, "record": record}

    def contribution(self, driver_id: str, trip_fare_usd: float = 0.0) -> dict[str, Any]:
        stats = self.pipeline.driver_stats(driver_id)
        if not stats:
            return {
                "driver_id": driver_id,
                "packets": 0,
                "estimated_total_usd": 0.0,
                "app_earnings_usd": 0.0,
                "depin_rewards_usd": 0.0,
            }
        return estimate_rewards(stats, trip_fare_usd=trip_fare_usd)

    def leaderboard(self) -> dict[str, Any]:
        rows = self.pipeline.all_driver_stats()
        ranked = sorted(rows, key=lambda row: row.get("reward_weight", 0.0), reverse=True)
        return {
            "drivers": [estimate_rewards(row) for row in ranked[:25]],
            "tree": self.pipeline.tree_summary(),
        }


class KairoHandler(BaseHTTPRequestHandler):
    api = KairoApi()

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length))

    def _send(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        parts = [part for part in parsed.path.split("/") if part]

        try:
            if parsed.path in {"/healthz", "/health"}:
                return self._send(HTTPStatus.OK, {"status": "ok", "service": "kairo-api"})
            if len(parts) >= 3 and parts[0] == "api" and parts[1] == "drivers":
                driver_id = parts[2]
                if len(parts) == 4 and parts[3] == "contribution":
                    qs = parse_qs(parsed.query)
                    fare = float((qs.get("trip_fare_usd") or ["0"])[0])
                    return self._send(HTTPStatus.OK, self.api.contribution(driver_id, fare))
                return self._send(HTTPStatus.OK, self.api.get_driver(driver_id))
            if parsed.path == "/api/contribution/leaderboard":
                return self._send(HTTPStatus.OK, self.api.leaderboard())
            self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
        except KeyError as exc:
            self._send(HTTPStatus.NOT_FOUND, {"error": str(exc)})
        except Exception as exc:  # noqa: BLE001
            self._send(HTTPStatus.BAD_REQUEST, {"error": str(exc)})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        try:
            body = self._read_json()
            if parsed.path == "/api/drivers":
                return self._send(HTTPStatus.CREATED, self.api.create_driver(body))
            if parsed.path == "/api/telemetry":
                return self._send(HTTPStatus.ACCEPTED, self.api.submit_telemetry(body))
            self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
        except KeyError as exc:
            self._send(HTTPStatus.NOT_FOUND, {"error": str(exc)})
        except ValueError as exc:
            self._send(HTTPStatus.UNAUTHORIZED, {"error": str(exc)})
        except Exception as exc:  # noqa: BLE001
            self._send(HTTPStatus.BAD_REQUEST, {"error": str(exc)})

    def log_message(self, fmt: str, *args: Any) -> None:
        return


def main() -> None:
    import os

    host = os.environ.get("KAIRO_API_HOST", "0.0.0.0")
    port = int(os.environ.get("KAIRO_API_PORT", "8091"))
    server = ThreadingHTTPServer((host, port), KairoHandler)
    print(f"Kairo API listening on http://{host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

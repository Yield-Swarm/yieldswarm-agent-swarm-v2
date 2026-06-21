"""Kairo HTTP API — driver identity, signed telemetry, contribution dashboard."""

from __future__ import annotations

import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse

from kairo.services.identity import recover_driver, register_driver
from kairo.services.telemetry_pipeline import TelemetryPipeline
from kairo.services.yslr_api import YslrApi


class KairoApi:
    def __init__(self) -> None:
        self.pipeline = TelemetryPipeline()
        self.drivers = self.pipeline.drivers
        self.yslr = YslrApi()

    def create_driver(self, body: dict[str, Any]) -> dict[str, Any]:
        driver_id = body.get("driver_id")
        recovery_passphrase = body.get("recovery_passphrase")
        result = register_driver(
            driver_id=driver_id,
            recovery_passphrase=recovery_passphrase,
            store=self.drivers,
            mirror_vault=body.get("mirror_vault", True),
        )
        # Mnemonic returned once at registration — client must persist offline
        return result.to_response(include_mnemonic=True)

    def recover_driver(self, body: dict[str, Any]) -> dict[str, Any]:
        mnemonic = body["mnemonic"]
        identity = recover_driver(
            mnemonic,
            passphrase=body.get("passphrase", ""),
            driver_id=body.get("driver_id"),
            recovery_passphrase=body.get("recovery_passphrase"),
            store=self.drivers,
        )
        return {"recovered": True, "identity": identity.to_public_dict()}

    def unlock_backup(self, driver_id: str, body: dict[str, Any]) -> dict[str, Any]:
        passphrase = body["recovery_passphrase"]
        mnemonic = self.drivers.unlock_mnemonic(driver_id, passphrase)
        return {"driver_id": driver_id, "mnemonic": mnemonic}

    def wallet_meta(self, driver_id: str) -> dict[str, Any]:
        meta = self.drivers.get_wallet_meta(driver_id)
        if not meta:
            raise KeyError("driver not found")
        return meta

    def get_driver(self, driver_id: str) -> dict[str, Any]:
        identity = self.drivers.get(driver_id)
        if not identity:
            raise KeyError("driver not found")
        return identity.to_public_dict()

    def submit_telemetry(self, body: dict[str, Any]) -> dict[str, Any]:
        return self.pipeline.submit(body)

    def submit_telemetry_batch(self, body: dict[str, Any]) -> dict[str, Any]:
        return self.pipeline.process_batch(body.get("samples", body.get("events", [])))

    def contribution(self, driver_id: str, trip_fare_usd: float = 0.0) -> dict[str, Any]:
        return self.pipeline.contribution(driver_id, trip_fare_usd)

    def leaderboard(self) -> dict[str, Any]:
        return self.pipeline.leaderboard()


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
                if len(parts) == 4 and parts[3] == "wallet":
                    return self._send(HTTPStatus.OK, self.api.wallet_meta(driver_id))
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
            if parsed.path == "/api/drivers/recover":
                return self._send(HTTPStatus.OK, self.api.recover_driver(body))
            if parsed.path.startswith("/api/drivers/") and parsed.path.endswith("/unlock"):
                driver_id = parsed.path.split("/")[3]
                return self._send(HTTPStatus.OK, self.api.unlock_backup(driver_id, body))
            if parsed.path == "/api/telemetry":
                return self._send(HTTPStatus.ACCEPTED, self.api.submit_telemetry(body))
            if parsed.path == "/api/telemetry/batch":
                return self._send(HTTPStatus.ACCEPTED, self.api.submit_telemetry_batch(body))
            if parsed.path == "/api/yslr/encrypt":
                return self._send(HTTPStatus.OK, self.api.yslr.encrypt(body))
            if parsed.path == "/api/yslr/decrypt":
                return self._send(HTTPStatus.OK, self.api.yslr.decrypt(body))
            if parsed.path == "/api/yslr/keys":
                return self._send(HTTPStatus.CREATED, self.api.yslr.generate_keys(body))
            if parsed.path == "/api/yslr/telemetry":
                return self._send(HTTPStatus.OK, self.api.yslr.encrypt_telemetry(body))
            if parsed.path == "/api/zk/prove/treasury":
                return self._send(HTTPStatus.OK, self.api.yslr.prove_treasury(body))
            if parsed.path == "/api/zk/verify":
                return self._send(HTTPStatus.OK, self.api.yslr.verify_zk(body))
            if parsed.path == "/api/yslr/mutation-seed":
                return self._send(HTTPStatus.OK, self.api.yslr.mutation_seed(body))
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

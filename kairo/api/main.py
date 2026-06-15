"""Kairo API — identity, telemetry, rewards."""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from kairo.models.identity import create_identity
from kairo.models.telemetry import create_telemetry
from kairo.services.pipeline import batch_route, route_telemetry
from kairo.services.rewards import calculate_ride_economics, driver_contribution_summary

VAULT_CURRENT_USD = float(os.getenv("KAIRO_VAULT_CURRENT_USD", "43000"))


class KairoHandler(BaseHTTPRequestHandler):
    server_version = "KairoAPI/1.0"

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, sort_keys=True).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path in {"/", "/healthz"}:
            self._send_json(200, {"service": "kairo", "status": "ok"})
            return
        if self.path == "/api/vault/progress":
            summary = driver_contribution_summary([], VAULT_CURRENT_USD)
            self._send_json(200, summary)
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid json"})
            return

        if self.path == "/api/identity/create":
            identity = create_identity()
            self._send_json(201, identity.to_dict())
            return

        if self.path == "/api/telemetry/ingest":
            event = create_telemetry(
                driver_id=data["driver_id"],
                evm_address=data["evm_address"],
                latitude=float(data["latitude"]),
                longitude=float(data["longitude"]),
                speed_mps=float(data.get("speed_mps", 0)),
                heading_deg=float(data.get("heading_deg", 0)),
                ride_id=data.get("ride_id"),
                trip_phase=data.get("trip_phase", "idle"),
            )
            node = route_telemetry(event)
            economics = calculate_ride_economics(
                float(data.get("fare_usd", 0)),
                node,
            )
            self._send_json(200, {
                "event": event.canonical_payload(),
                "mandelbrot": {
                    "shard_id": node.shard_id,
                    "reward_weight": node.reward_weight,
                },
                "economics": economics.to_dict(),
            })
            return

        if self.path == "/api/telemetry/batch":
            events = [
                create_telemetry(
                    driver_id=e["driver_id"],
                    evm_address=e["evm_address"],
                    latitude=float(e["latitude"]),
                    longitude=float(e["longitude"]),
                )
                for e in data.get("events", [])
            ]
            self._send_json(200, {"routed": batch_route(events)})
            return

        self._send_json(404, {"error": "not found"})


def main() -> None:
    host = os.getenv("KAIRO_HOST", "0.0.0.0")
    port = int(os.getenv("KAIRO_PORT", "8787"))
    server = ThreadingHTTPServer((host, port), KairoHandler)
    print(f"Kairo API listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

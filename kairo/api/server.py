"""Kairo REST API — driver identity, telemetry, earnings."""

from __future__ import annotations

import json
import os
import sys
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

# Allow running as `python -m kairo.api.server`
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from kairo.identity.driver_wallet import create_driver_identity, create_ephemeral_driver, verify_signature
from kairo.payments.fees import RideFare, calculate_earnings
from kairo.payments.service import KairoPaymentService
from kairo.pipeline.mandelbrot_router import MandelbrotPipeline
from kairo.telemetry.collector import TelemetryCollector
from kairo.telemetry.schema import DrivingTelemetry, GeoPoint, SignedTelemetry


# In-memory driver registry (swap for DB in production).
_drivers: dict[str, dict[str, Any]] = {}
_contributions: dict[str, dict[str, Any]] = {}


def _json_response(handler: BaseHTTPRequestHandler, status: int, body: dict) -> None:
    payload = json.dumps(body).encode()
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type")
    handler.end_headers()
    handler.wfile.write(payload)


class KairoHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: Any) -> None:
        pass  # quiet in production

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        if path == "/api/kairo/health":
            _json_response(self, 200, {"status": "ok", "service": "kairo"})
        elif path == "/api/kairo/drivers":
            _json_response(self, 200, {"drivers": list(_drivers.values())})
        elif path.startswith("/api/kairo/drivers/"):
            driver_id = path.split("/")[-1]
            if driver_id not in _drivers:
                _json_response(self, 404, {"error": "driver not found"})
            else:
                _json_response(self, 200, _drivers[driver_id])
        elif path == "/api/kairo/contributions":
            qs = parse_qs(parsed.query)
            driver_id = qs.get("driver_id", [None])[0]
            if driver_id:
                data = _contributions.get(driver_id, {"events": 0, "reward_weight": 0})
                _json_response(self, 200, {"driver_id": driver_id, **data})
            else:
                _json_response(self, 200, {"contributions": _contributions})
        elif path == "/api/kairo/dashboard":
            self._serve_dashboard()
        else:
            _json_response(self, 404, {"error": "not found"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw.decode())
        except json.JSONDecodeError:
            _json_response(self, 400, {"error": "invalid json"})
            return

        if path == "/api/kairo/drivers/register":
            self._register_driver(body)
        elif path == "/api/kairo/telemetry":
            self._ingest_telemetry(body)
        elif path == "/api/kairo/rides/complete":
            self._complete_ride(body)
        else:
            _json_response(self, 404, {"error": "not found"})

    def _register_driver(self, body: dict) -> None:
        driver_id = body.get("driver_id")
        if driver_id:
            identity, _ = create_driver_identity(driver_id)
        else:
            identity, _ = create_ephemeral_driver()
            driver_id = identity.driver_id

        record = {
            "driver_id": driver_id,
            "evm_address": identity.evm_address,
            "iotex_address": identity.iotex_address,
            "public_key_hex": identity.public_key_hex,
        }
        _drivers[driver_id] = record
        _contributions.setdefault(driver_id, {"events": 0, "reward_weight": 0.0, "zones": []})
        _json_response(self, 201, record)

    def _ingest_telemetry(self, body: dict) -> None:
        signed_data = body.get("signed") or body
        tel = signed_data.get("telemetry") or signed_data
        signature = signed_data.get("signature", "")

        loc = tel.get("location")
        telemetry = DrivingTelemetry(
            driver_id=tel["driver_id"],
            evm_address=tel["evm_address"],
            iotex_address=tel["iotex_address"],
            timestamp=tel.get("timestamp", ""),
            session_id=tel.get("session_id", ""),
            location=GeoPoint(**loc) if loc else None,
            speed_mph=tel.get("speed_mph"),
            heading_deg=tel.get("heading_deg"),
            distance_miles=tel.get("distance_miles"),
            duration_sec=tel.get("duration_sec"),
            vehicle_id=tel.get("vehicle_id"),
            shard_id=tel.get("shard_id", 0),
            extra=tel.get("extra", {}),
        )
        signed = SignedTelemetry(telemetry=telemetry, signature=signature)

        pipeline = MandelbrotPipeline(ingest_url="")  # local only
        from kairo.identity.driver_wallet import DriverIdentity

        identity = DriverIdentity(
            driver_id=telemetry.driver_id,
            evm_address=telemetry.evm_address,
            iotex_address=telemetry.iotex_address,
            public_key_hex="",
        )
        if not verify_signature(identity, telemetry.payload_for_signing(), signature):
            _json_response(self, 401, {"error": "invalid signature"})
            return

        from kairo.pipeline.mandelbrot_router import classify_telemetry

        zone = classify_telemetry(signed)
        driver_id = telemetry.driver_id
        contrib = _contributions.setdefault(driver_id, {"events": 0, "reward_weight": 0.0, "zones": []})
        contrib["events"] += 1
        contrib["reward_weight"] = round(contrib["reward_weight"] + zone.reward_weight, 4)
        if zone.zone_id not in contrib["zones"]:
            contrib["zones"].append(zone.zone_id)

        _json_response(self, 200, {
            "accepted": True,
            "classification": {
                "zone_id": zone.zone_id,
                "tree_path": zone.tree_path,
                "shard_id": zone.shard_id,
                "reward_weight": zone.reward_weight,
            },
        })

    def _complete_ride(self, body: dict) -> None:
        driver_id = body.get("driver_id", "")
        ride_id = body.get("ride_id", f"ride-{driver_id}")
        fare = RideFare(
            base_fare_usd=Decimal(str(body.get("base_fare_usd", "5.00"))),
            distance_miles=Decimal(str(body.get("distance_miles", "3.0"))),
            duration_min=Decimal(str(body.get("duration_min", "12"))),
            surge_multiplier=Decimal(str(body.get("surge_multiplier", "1.0"))),
        )
        depin = Decimal(str(body.get("depin_reward_usd", "0")))
        crypto = Decimal(str(body.get("crypto_reward_usd", "0")))
        instant = bool(body.get("instant_cashout", False))

        driver = _drivers.get(driver_id, {})
        evm = driver.get("evm_address", body.get("evm_address", ""))

        svc = KairoPaymentService()
        breakdown = svc.process_ride_completion(
            ride_id=ride_id,
            driver_id=driver_id,
            driver_evm_address=evm,
            fare=fare,
            depin_reward_usd=depin,
            crypto_reward_usd=crypto,
            instant_cashout=instant,
        )
        _json_response(self, 200, breakdown.to_dict())

    def _serve_dashboard(self) -> None:
        dashboard_path = Path(__file__).resolve().parents[1] / "dashboard" / "index.html"
        if not dashboard_path.exists():
            _json_response(self, 404, {"error": "dashboard not found"})
            return
        content = dashboard_path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(content)


def main() -> None:
    host = os.environ.get("KAIRO_API_HOST", "0.0.0.0")
    port = int(os.environ.get("KAIRO_API_PORT", "3001"))
    server = HTTPServer((host, port), KairoHandler)
    print(f"[kairo] API listening on http://{host}:{port}")
    print(f"  Dashboard: http://{host}:{port}/api/kairo/dashboard")
    server.serve_forever()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Kairo CLI — driver identity, telemetry ingest, contributions."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


def main() -> None:
    if len(sys.argv) < 2:
        print(json.dumps({"error": "usage: kairo/cli.py <command> [args]"}))
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "ping":
        print(json.dumps({"ok": True}))
        return

    if cmd == "register":
        from kairo.services.identity import register_driver

        body = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        result = register_driver(
            driver_id=body.get("driver_id"),
            recovery_passphrase=body.get("recovery_passphrase"),
        )
        print(json.dumps(result.to_response(include_mnemonic=True)))
        return

    if cmd == "recover":
        from kairo.services.identity import recover_driver

        body = json.loads(sys.argv[2])
        identity = recover_driver(
            body["mnemonic"],
            passphrase=body.get("passphrase", ""),
            driver_id=body.get("driver_id"),
            recovery_passphrase=body.get("recovery_passphrase"),
        )
        print(json.dumps({"recovered": True, "identity": identity.to_public_dict()}))
        return

    if cmd == "ingest":
        from kairo.telemetry.ingest import ingest_sample, ingest_signed_event

        raw = json.loads(sys.argv[2])
        if "signature" in raw:
            event, err = ingest_signed_event(raw)
        else:
            event, err = ingest_sample(raw)
        if err:
            print(json.dumps({"ok": False, "error": err}))
            sys.exit(1)
        print(json.dumps({"ok": True, "result": event}))
        return

    if cmd == "contributions":
        from kairo.telemetry.ingest import list_contributions

        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 50
        print(json.dumps({"contributions": list_contributions(limit)}))
        return

    if cmd == "simulate-drive":
        from kairo.client.telemetry import DriverTelemetryClient
        from kairo.services.identity import DriverStore, generate_driver_identity

        body = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        driver_id = body.get("driver_id", "sim-driver")
        store = DriverStore()
        if not store.get(driver_id):
            store.save(generate_driver_identity(driver_id))

        client = DriverTelemetryClient(driver_id)
        coords = body.get("coords", [[39.7392, -104.9903], [39.75, -104.98], [39.76, -104.97]])
        results = []
        for lat, lon in coords:
            sample = client.collect(lat, lon, speed_kmh=35.0, distance_km=1.2, duration_seconds=60)
            results.append(client.submit_sample(sample))
        print(json.dumps({"ok": True, "packets": len(results), "last": results[-1] if results else None}))
        return

    print(json.dumps({"error": f"unknown command: {cmd}"}))
    sys.exit(1)


if __name__ == "__main__":
    main()

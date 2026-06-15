"""Signed driving telemetry collection for Kairo drivers."""

from __future__ import annotations

import json
import time
from typing import Any, Dict, Optional

from . import identity, mandelbrot


def build_telemetry_message(payload: Dict[str, Any]) -> str:
    """Canonical message string for signing."""
    canonical = {
        "driverId": payload.get("driverId"),
        "timestamp": payload.get("timestamp", time.time()),
        "lat": payload.get("lat"),
        "lng": payload.get("lng"),
        "speedKmh": payload.get("speedKmh"),
        "distanceKm": payload.get("distanceKm"),
        "durationMin": payload.get("durationMin"),
        "tripId": payload.get("tripId"),
    }
    return json.dumps(canonical, sort_keys=True, separators=(",", ":"))


def submit_telemetry(
    driver_id: str,
    payload: Dict[str, Any],
    signature: Optional[str] = None,
    store_dir: Optional[str] = None,
) -> Dict[str, Any]:
    """Validate signature and route telemetry into Mandelbrot."""
    ident = identity.load_identity(driver_id, store_dir)
    if not ident:
        raise KeyError(f"unknown driver {driver_id}")

    message = build_telemetry_message({**payload, "driverId": driver_id})
    sig = signature
    if not sig:
        signed = identity.sign_message(driver_id, message, store_dir)
        sig = signed["signature"]
    elif not identity.verify_signature(ident.evm_address, message, sig):
        raise ValueError("invalid telemetry signature")

    fp = identity.identity_fingerprint(ident)
    result = mandelbrot.ingest_event(driver_id, fp, payload, sig)
    stats = mandelbrot.load_shard_stats(driver_id, fp)
    return {
        "driverId": driver_id,
        "evmAddress": ident.evm_address,
        "iotexAddress": ident.iotex_address,
        "message": message,
        "signature": sig,
        "routing": result,
        "contribution": stats,
    }

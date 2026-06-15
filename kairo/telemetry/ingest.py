"""
Signed telemetry ingestion and Mandelbrot / Tree of Life routing.
"""

from __future__ import annotations

import json
import secrets
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from kairo.identity.verify import verify_telemetry_event
from kairo.pow.mandelbrot import compute_mandelbrot_score, shard_for_score
from kairo.models.driver import DriverContribution, SignedTelemetryEvent

_EVENTS_PATH = Path(__file__).resolve().parents[1] / "data" / "telemetry_events.jsonl"
_CONTRIBUTIONS_PATH = Path(__file__).resolve().parents[1] / "data" / "contributions.json"


def _append_event(event: dict[str, Any]) -> None:
    _EVENTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    with _EVENTS_PATH.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event) + "\n")


def _load_contributions() -> dict[str, dict]:
    if not _CONTRIBUTIONS_PATH.exists():
        return {}
    return json.loads(_CONTRIBUTIONS_PATH.read_text(encoding="utf-8"))


def _save_contributions(data: dict[str, dict]) -> None:
    _CONTRIBUTIONS_PATH.parent.mkdir(parents=True, exist_ok=True)
    _CONTRIBUTIONS_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")


def ingest_signed_event(raw: dict[str, Any]) -> tuple[SignedTelemetryEvent | None, str | None]:
    ok, reason = verify_telemetry_event(raw)
    if not ok:
        return None, reason

    payload = raw.get("payload", {})
    lat = float(payload.get("latitude", 0))
    lon = float(payload.get("longitude", 0))
    miles = float(payload.get("miles", 0))

    mandelbrot_score = compute_mandelbrot_score(lat, lon, payload.get("speed_mph", 0))
    shard = shard_for_score(mandelbrot_score)

    event = SignedTelemetryEvent(
        driver_id=raw["driver_id"],
        evm_address=raw["evm_address"],
        event_type=raw.get("event_type", "drive.segment"),
        payload=payload,
        nonce=raw["nonce"],
        timestamp=raw["timestamp"],
        signature_hex=raw["signature_hex"],
        mandelbrot_score=mandelbrot_score,
        tree_of_life_shard=shard,
    )
    _append_event(event.to_dict())
    _update_contribution(event, miles)
    return event, None


def _update_contribution(event: SignedTelemetryEvent, miles: float) -> None:
    contribs = _load_contributions()
    c = contribs.get(event.driver_id, {
        "driver_id": event.driver_id,
        "evm_address": event.evm_address,
        "event_count": 0,
        "total_miles": 0.0,
        "mandelbrot_points": 0.0,
        "estimated_rewards_usd": 0.0,
        "depin_rewards_usd": 0.0,
        "last_event_at": None,
    })
    c["event_count"] += 1
    c["total_miles"] = round(c["total_miles"] + miles, 4)
    c["mandelbrot_points"] = round(c["mandelbrot_points"] + (event.mandelbrot_score or 0), 4)
    # Reward estimate: $0.02/mile app + DePIN multiplier from Mandelbrot score
    app_rev = miles * 0.02
    depin = (event.mandelbrot_score or 0) * 0.001
    c["estimated_rewards_usd"] = round(c["estimated_rewards_usd"] + app_rev + depin, 4)
    c["depin_rewards_usd"] = round(c["depin_rewards_usd"] + depin, 4)
    c["last_event_at"] = event.timestamp
    contribs[event.driver_id] = c
    _save_contributions(contribs)


def list_contributions(limit: int = 50) -> list[DriverContribution]:
    contribs = _load_contributions()
    items = sorted(
        contribs.values(),
        key=lambda x: x.get("mandelbrot_points", 0),
        reverse=True,
    )[:limit]
    return [DriverContribution(**c) for c in items]


def build_sample_signed_event(
    private_key_hex: str,
    driver_id: str,
    evm_address: str,
) -> dict[str, Any]:
    """Dev helper: build a signed drive segment for testing."""
    from kairo.identity.verify import sign_telemetry_event

    payload = {
        "latitude": 37.7749,
        "longitude": -122.4194,
        "speed_mph": 35.5,
        "miles": 1.2,
        "heading": 180,
    }
    return sign_telemetry_event(
        private_key_hex,
        driver_id,
        evm_address,
        "drive.segment",
        payload,
        nonce=secrets.token_hex(16),
        timestamp=datetime.now(timezone.utc).isoformat(),
    )

"""Signed driver telemetry for Kairo → YieldSwarm Mandelbrot pipeline."""

from __future__ import annotations

import hashlib
import json
import time
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from kairo.models.identity import sign_message


@dataclass
class TelemetryEvent:
    event_id: str
    driver_id: str
    evm_address: str
    timestamp: str
    latitude: float
    longitude: float
    speed_mps: float
    heading_deg: float
    ride_id: Optional[str] = None
    trip_phase: str = "idle"  # idle | pickup | en_route | dropoff
    depin_earnings_usd: float = 0.0
    customer_fee_pct: float = 0.01
    driver_pay_multiplier: float = 2.0
    metadata: dict[str, Any] = field(default_factory=dict)
    signature: Optional[str] = None

    def canonical_payload(self) -> dict[str, Any]:
        data = asdict(self)
        data.pop("signature", None)
        return data

    def sign(self, identity_seed: str) -> "TelemetryEvent":
        canonical = json.dumps(self.canonical_payload(), sort_keys=True)
        result = sign_message(identity_seed, canonical)
        self.signature = result["signature"]
        return self


def create_telemetry(
    driver_id: str,
    evm_address: str,
    latitude: float,
    longitude: float,
    *,
    speed_mps: float = 0.0,
    heading_deg: float = 0.0,
    ride_id: Optional[str] = None,
    trip_phase: str = "idle",
    identity_seed: Optional[str] = None,
) -> TelemetryEvent:
    event = TelemetryEvent(
        event_id=str(uuid.uuid4()),
        driver_id=driver_id,
        evm_address=evm_address,
        timestamp=datetime.now(timezone.utc).isoformat(),
        latitude=latitude,
        longitude=longitude,
        speed_mps=speed_mps,
        heading_deg=heading_deg,
        ride_id=ride_id,
        trip_phase=trip_phase,
    )
    if identity_seed:
        event.sign(identity_seed)
    return event


def telemetry_hash(event: TelemetryEvent) -> str:
    """Deterministic hash for Mandelbrot coordinate seeding."""
    payload = json.dumps(event.canonical_payload(), sort_keys=True)
    return hashlib.sha256(payload.encode()).hexdigest()

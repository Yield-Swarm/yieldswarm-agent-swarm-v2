"""Cryptographically signed driving telemetry for YieldSwarm DePIN nodes."""

from __future__ import annotations

import hashlib
import json
import time
import uuid
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from kairo.identity.driver import sign_message


@dataclass
class TelemetryPoint:
    timestamp: str
    latitude: float
    longitude: float
    speed_mps: float
    heading_deg: float
    altitude_m: float = 0.0
    accuracy_m: float = 5.0
    battery_pct: Optional[float] = None

    def canonical_json(self) -> str:
        return json.dumps(asdict(self), sort_keys=True, separators=(",", ":"))


@dataclass
class SignedTelemetryBatch:
    batch_id: str
    driver_id: str
    node_shard: int
    points: List[TelemetryPoint]
    signature: str
    signer_evm: str
    signer_iotex: str
    created_at: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "batch_id": self.batch_id,
            "driver_id": self.driver_id,
            "node_shard": self.node_shard,
            "points": [asdict(p) for p in self.points],
            "signature": self.signature,
            "signer_evm": self.signer_evm,
            "signer_iotex": self.signer_iotex,
            "created_at": self.created_at,
        }


def _batch_digest(driver_id: str, points: List[TelemetryPoint]) -> str:
    payload = "|".join(p.canonical_json() for p in points)
    return hashlib.sha256(f"{driver_id}:{payload}".encode()).hexdigest()


def sign_telemetry_batch(
    *,
    driver_id: str,
    private_key_hex: str,
    points: List[TelemetryPoint],
    node_shard: int = 0,
) -> SignedTelemetryBatch:
    if not points:
        raise ValueError("telemetry batch must contain at least one point")

    digest = _batch_digest(driver_id, points)
    signed = sign_message(private_key_hex, digest)

    return SignedTelemetryBatch(
        batch_id=str(uuid.uuid4()),
        driver_id=driver_id,
        node_shard=node_shard,
        points=points,
        signature=signed["signature"],
        signer_evm=signed["signer_evm"],
        signer_iotex=signed["signer_iotex"],
        created_at=datetime.now(timezone.utc).isoformat(),
    )


def sample_telemetry(
    driver_id: str,
    private_key_hex: str,
    *,
    lat: float = 39.7392,
    lon: float = -104.9903,
    speed_mps: float = 12.5,
    node_shard: int = 0,
) -> SignedTelemetryBatch:
    """Generate a signed telemetry batch (for testing / simulation)."""
    now = time.time()
    points = [
        TelemetryPoint(
            timestamp=datetime.fromtimestamp(now - 30, tz=timezone.utc).isoformat(),
            latitude=lat,
            longitude=lon,
            speed_mps=speed_mps,
            heading_deg=90.0,
        ),
        TelemetryPoint(
            timestamp=datetime.fromtimestamp(now, tz=timezone.utc).isoformat(),
            latitude=lat + 0.001,
            longitude=lon + 0.001,
            speed_mps=speed_mps + 1.0,
            heading_deg=92.0,
        ),
    ]
    return sign_telemetry_batch(
        driver_id=driver_id,
        private_key_hex=private_key_hex,
        points=points,
        node_shard=node_shard,
    )

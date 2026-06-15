"""
Kairo driver data models.

Every Kairo driver is a YieldSwarm DePIN node with a persistent cryptographic
identity (IoTeX + EVM compatible) and signed telemetry contributions.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class DriverIdentity:
    """Persistent cryptographic identity for a Kairo driver."""

    driver_id: str
    evm_address: str
    iotex_address: str
    public_key_hex: str
    created_at: str = field(default_factory=utc_now)
    device_fingerprint: Optional[str] = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class SignedTelemetryEvent:
    """Cryptographically signed driving telemetry envelope."""

    driver_id: str
    evm_address: str
    event_type: str
    payload: dict[str, Any]
    nonce: str
    timestamp: str
    signature_hex: str
    mandelbrot_score: Optional[float] = None
    tree_of_life_shard: Optional[str] = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class DriverContribution:
    """Aggregated contribution stats for rewards estimation."""

    driver_id: str
    evm_address: str
    event_count: int
    total_miles: float
    mandelbrot_points: float
    estimated_rewards_usd: float
    depin_rewards_usd: float
    last_event_at: Optional[str] = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

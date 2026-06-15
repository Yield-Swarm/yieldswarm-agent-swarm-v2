"""Kairo driver identity and contribution models."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4


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
    # Encrypted at rest when persisted; never returned by public APIs.
    encrypted_private_key: str | None = None

    def to_public_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data.pop("encrypted_private_key", None)
        return data


@dataclass
class SignedTelemetry:
    """Cryptographically signed driving telemetry packet."""

    driver_id: str
    evm_address: str
    payload: dict[str, Any]
    signature: str
    signed_at: str = field(default_factory=utc_now)
    telemetry_id: str = field(default_factory=lambda: str(uuid4()))

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class ContributionSummary:
    """Aggregated contribution stats for rewards estimation."""

    driver_id: str
    evm_address: str
    total_packets: int
    total_distance_km: float
    total_drive_seconds: int
    mandelbrot_nodes: int
    estimated_rewards_usd: float
    app_earnings_usd: float
    depin_rewards_usd: float
    last_contribution_at: str | None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

"""Telemetry data models for Kairo drivers."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class GeoPoint:
    lat: float
    lng: float
    accuracy_m: Optional[float] = None


@dataclass
class DrivingTelemetry:
    """A single signed telemetry event from a Kairo driver."""

    driver_id: str
    evm_address: str
    iotex_address: str
    timestamp: str = field(default_factory=_utc_now)
    session_id: str = ""
    location: Optional[GeoPoint] = None
    speed_mph: Optional[float] = None
    heading_deg: Optional[float] = None
    distance_miles: Optional[float] = None
    duration_sec: Optional[int] = None
    vehicle_id: Optional[str] = None
    shard_id: int = 0
    # Mandelbrot routing metadata
    mandelbrot_zone: Optional[str] = None
    tree_of_life_path: Optional[str] = None
    extra: dict[str, Any] = field(default_factory=dict)

    def payload_for_signing(self) -> dict[str, Any]:
        """Canonical dict used for cryptographic signing (excludes signature)."""
        d = asdict(self)
        if self.location:
            d["location"] = asdict(self.location)
        return d


@dataclass
class SignedTelemetry:
    """Telemetry + cryptographic signature."""

    telemetry: DrivingTelemetry
    signature: str
    signature_scheme: str = "eip191"

    def to_dict(self) -> dict[str, Any]:
        return {
            "telemetry": self.telemetry.payload_for_signing(),
            "signature": self.signature,
            "signature_scheme": self.signature_scheme,
        }

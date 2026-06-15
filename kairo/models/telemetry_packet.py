"""Driver telemetry samples — collection → signing → Mandelbrot routing."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional
from uuid import uuid4


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class DriverTelemetrySample:
    """Raw telemetry collected from a Kairo driver device."""

    driver_id: str
    evm_address: str
    latitude: float
    longitude: float
    speed_kmh: float = 0.0
    heading_deg: float = 0.0
    distance_km: float = 0.0
    duration_seconds: int = 0
    ride_id: Optional[str] = None
    trip_phase: str = "idle"  # idle | pickup | en_route | dropoff
    fare_usd: float = 0.0
    altitude_m: Optional[float] = None
    accuracy_m: Optional[float] = None
    device_id: Optional[str] = None
    captured_at: str = field(default_factory=_utc_now)
    sample_id: str = field(default_factory=lambda: str(uuid4()))

    def to_payload(self) -> dict[str, Any]:
        """Canonical payload for signing and Mandelbrot routing."""
        return {
            "sample_id": self.sample_id,
            "driver_id": self.driver_id,
            "evm_address": self.evm_address,
            "latitude": round(self.latitude, 7),
            "longitude": round(self.longitude, 7),
            "speed_kmh": round(self.speed_kmh, 3),
            "heading_deg": round(self.heading_deg, 2),
            "distance_km": round(self.distance_km, 4),
            "duration_seconds": int(self.duration_seconds),
            "ride_id": self.ride_id,
            "trip_phase": self.trip_phase,
            "fare_usd": round(self.fare_usd, 2),
            "altitude_m": self.altitude_m,
            "accuracy_m": self.accuracy_m,
            "device_id": self.device_id,
            "captured_at": self.captured_at,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "DriverTelemetrySample":
        return cls(
            driver_id=data["driver_id"],
            evm_address=data["evm_address"],
            latitude=float(data["latitude"]),
            longitude=float(data["longitude"]),
            speed_kmh=float(data.get("speed_kmh", 0)),
            heading_deg=float(data.get("heading_deg", 0)),
            distance_km=float(data.get("distance_km", 0)),
            duration_seconds=int(data.get("duration_seconds", 0)),
            ride_id=data.get("ride_id"),
            trip_phase=data.get("trip_phase", "idle"),
            fare_usd=float(data.get("fare_usd", 0)),
            altitude_m=data.get("altitude_m"),
            accuracy_m=data.get("accuracy_m"),
            device_id=data.get("device_id"),
            captured_at=data.get("captured_at", _utc_now()),
            sample_id=data.get("sample_id", str(uuid4())),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

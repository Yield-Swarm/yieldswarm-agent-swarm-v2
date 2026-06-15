"""Domain models for Kairo → YieldSwarm bridge."""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field, field_validator


class GpsPoint(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    altitude_m: float | None = None
    accuracy_m: float | None = None


class RouteSegment(BaseModel):
    segment_id: str
    points: list[GpsPoint] = Field(default_factory=list)
    distance_km: float = Field(default=0, ge=0)


class TelemetryPayload(BaseModel):
    """Canonical telemetry body — must match client signing input exactly."""

    driver_id: str
    kairo_session_id: str
    recorded_at: datetime
    gps: GpsPoint
    speed_mps: float = Field(..., ge=0)
    acceleration_mps2: float
    heading_deg: float | None = Field(default=None, ge=0, lt=360)
    route: RouteSegment | None = None

    def canonical_dict(self) -> dict[str, Any]:
        return {
            "driver_id": self.driver_id,
            "kairo_session_id": self.kairo_session_id,
            "recorded_at": self.recorded_at.isoformat(),
            "gps": self.gps.model_dump(exclude_none=True),
            "speed_mps": self.speed_mps,
            "acceleration_mps2": self.acceleration_mps2,
            "heading_deg": self.heading_deg,
            "route": self.route.model_dump(exclude_none=True) if self.route else None,
        }


class SignedTelemetryIn(BaseModel):
    payload: TelemetryPayload
    signature_hex: str = Field(..., pattern=r"^0x[a-fA-F0-9]+$")

    @field_validator("signature_hex")
    @classmethod
    def normalize_sig(cls, v: str) -> str:
        return v.lower()


class DriverIdentityOut(BaseModel):
    driver_id: str
    kairo_user_id: str
    evm_address: str
    iotex_address: str
    public_key_hex: str
    license_key: str
    created_at: datetime
    depin_helium_pubkey: str | None = None
    depin_grass_node_id: str | None = None


class DriverRegisterIn(BaseModel):
    kairo_user_id: str = Field(..., min_length=1, max_length=128)
    # Client-generated secp256k1 public key (hex, uncompressed 0x04...)
    public_key_hex: str = Field(..., pattern=r"^0x04[a-fA-F0-9]{128}$")
    registration_signature_hex: str = Field(..., pattern=r"^0x[a-fA-F0-9]+$")
    depin_helium_pubkey: str | None = None
    depin_grass_node_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class ServerKeygenOut(BaseModel):
    """Returned once when server generates identity (dev/onboarding fallback)."""

    driver_id: str
    mnemonic: str
    evm_address: str
    iotex_address: str
    public_key_hex: str
    license_key: str
    warning: str = "Store mnemonic securely — shown only once."


class MandelbrotRouteOut(BaseModel):
    shard_id: int
    tree_of_life_node: str
    helix_path: str
    yieldswarm_cron_slot: int


class DepinRewardEstimate(BaseModel):
    token: str
    amount_usd: float
    contribution_points: float
    description: str


class DriverPayQuote(BaseModel):
    driver_id: str
    base_pay_usd: float
    multiplier: float
    total_pay_usd: float
    eligible_for_2x: bool
    eligibility_reasons: list[str]
    rail: str
    destination: str


class DashboardSummary(BaseModel):
    driver_id: str
    kairo_user_id: str
    evm_address: str
    iotex_address: str
    total_distance_km: float
    signed_packets: int
    verified_packets: int
    active_shards: list[int]
    tree_nodes: list[str]
    depin_rewards: list[DepinRewardEstimate]
    pay_quote: DriverPayQuote
    last_telemetry_at: datetime | None


class PayoutRail(str, Enum):
    WISE = "wise"
    EVM = "evm"
    IOTEX = "iotex"

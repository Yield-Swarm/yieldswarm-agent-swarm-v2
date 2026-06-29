"""Pydantic models for device telemetry."""

from __future__ import annotations

from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


class DeviceStatus(str, Enum):
    ONLINE = "ONLINE"
    OFFLINE = "OFFLINE"
    DEGRADED = "DEGRADED"
    UNKNOWN = "UNKNOWN"


class DeviceStatsIn(BaseModel):
    """POST /api/telemetry/device-stats payload from edge stubs."""

    device_id: str = Field(..., min_length=1, max_length=128)
    encrypted_pow_id: Optional[str] = None
    encrypted_powui_id: Optional[str] = None
    cpu_percent: float = Field(..., ge=0, le=100)
    memory_percent: float = Field(..., ge=0, le=100)
    network_ok: bool = True
    hash_rate_mhs: Optional[float] = Field(None, ge=0)
    latency_ms: Optional[float] = Field(None, ge=0)
    temp_c: Optional[float] = None
    kind: str = "edge-worker"
    meta: dict[str, Any] = Field(default_factory=dict)

    @field_validator("device_id")
    @classmethod
    def strip_device_id(cls, v: str) -> str:
        return v.strip()


class DeviceRecord(BaseModel):
    device_id: str
    kind: str = "miner"
    host: Optional[str] = None
    status: DeviceStatus = DeviceStatus.UNKNOWN
    uptime_sec: Optional[float] = None
    hash_rate_mhs: Optional[float] = None
    latency_ms: Optional[float] = None
    cpu_percent: Optional[float] = None
    memory_percent: Optional[float] = None
    network_ok: Optional[bool] = None
    temp_c: Optional[float] = None
    encrypted_pow_id: Optional[str] = None
    encrypted_powui_id: Optional[str] = None
    last_seen_at: Optional[str] = None
    last_error: Optional[str] = None
    source: str = "poller"


class InfrastructureSnapshot(BaseModel):
    generated_at: str
    device_count: int
    online_count: int
    offline_count: int
    devices: list[DeviceRecord]
    aggregate_hash_rate_mhs: float
    avg_latency_ms: Optional[float]

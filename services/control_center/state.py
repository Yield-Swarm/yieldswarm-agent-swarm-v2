"""Thread-safe asyncio infrastructure state."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Optional

from services.control_center.models import DeviceRecord, DeviceStatus, InfrastructureSnapshot


class InfrastructureState:
    """In-memory device registry — safe for concurrent poller + HTTP handlers."""

    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._devices: dict[str, DeviceRecord] = {}

    async def upsert(self, record: DeviceRecord) -> None:
        async with self._lock:
            self._devices[record.device_id] = record

    async def mark_offline(self, device_id: str, error: str) -> None:
        async with self._lock:
            prev = self._devices.get(device_id)
            self._devices[device_id] = DeviceRecord(
                device_id=device_id,
                kind=prev.kind if prev else "unknown",
                host=prev.host if prev else None,
                status=DeviceStatus.OFFLINE,
                last_error=error,
                last_seen_at=datetime.now(timezone.utc).isoformat(),
                source=prev.source if prev else "poller",
            )

    async def snapshot(self) -> InfrastructureSnapshot:
        async with self._lock:
            devices = list(self._devices.values())

        online = [d for d in devices if d.status == DeviceStatus.ONLINE]
        offline = [d for d in devices if d.status == DeviceStatus.OFFLINE]
        hash_total = sum(d.hash_rate_mhs or 0 for d in devices)
        latencies = [d.latency_ms for d in devices if d.latency_ms is not None]
        avg_lat = sum(latencies) / len(latencies) if latencies else None

        return InfrastructureSnapshot(
            generated_at=datetime.now(timezone.utc).isoformat(),
            device_count=len(devices),
            online_count=len(online),
            offline_count=len(offline),
            devices=devices,
            aggregate_hash_rate_mhs=round(hash_total, 4),
            avg_latency_ms=round(avg_lat, 2) if avg_lat is not None else None,
        )

    async def get_device(self, device_id: str) -> Optional[DeviceRecord]:
        async with self._lock:
            return self._devices.get(device_id)


state = InfrastructureState()

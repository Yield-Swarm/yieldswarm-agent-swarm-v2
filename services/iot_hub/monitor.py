"""Device status monitoring for FWA_37KN9S-IoT."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any

from .adapters import get_adapter
from .registry import IoTDeviceRegistry


class DeviceMonitor:
    def __init__(self, registry: IoTDeviceRegistry | None = None):
        self.registry = registry or IoTDeviceRegistry()
        self.dry_run = os.environ.get("IOT_HUB_DRY_RUN", "1") == "1"

    def _device_row(self, record: Any) -> dict[str, Any]:
        row = record.to_dict()
        catalog = {d["id"]: d for d in self.registry.catalog_devices()}
        cat = catalog.get(record.device_id, {})
        row["check"] = cat.get("check")
        row["type"] = record.device_type
        return row

    def check_device(self, device_id: str) -> dict[str, Any]:
        record = self.registry.get_device(device_id)
        if not record:
            raise ValueError(f"device not found: {device_id}")
        result = get_adapter(self._device_row(record)).check(
            {**self._device_row(record), "device_id": device_id},
            dry_run=self.dry_run,
        )
        updated = self.registry.update_status(device_id, result.status, metrics=result.metrics)
        return {
            "device": updated.to_dict(),
            "check": result.to_dict(),
            "checked_at": datetime.now(timezone.utc).isoformat(),
        }

    def check_all(self) -> dict[str, Any]:
        results: list[dict[str, Any]] = []
        for record in self.registry.list_devices():
            try:
                results.append(self.check_device(record.device_id))
            except Exception as exc:
                results.append({
                    "device_id": record.device_id,
                    "error": str(exc),
                    "status": "error",
                })

        online = sum(1 for r in results if r.get("check", {}).get("status") == "online" or r.get("device", {}).get("status") == "online")
        total = len(results)
        return {
            "network_id": self.registry.network_id(),
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "dry_run": self.dry_run,
            "summary": {
                "total": total,
                "online": online,
                "healthy_ratio": round(online / total, 4) if total else 0.0,
            },
            "results": results,
        }

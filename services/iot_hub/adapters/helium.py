from __future__ import annotations

import json
import os
from typing import Any

from .base import CheckResult, DeviceAdapter
from .icmp import IcmpAdapter


class HeliumHotspotAdapter(DeviceAdapter):
    """Helium hotspot — API when keys configured, else ICMP to LAN IP if set."""

    device_type = "helium_hotspot"

    def check(self, device: dict[str, Any], *, dry_run: bool = False) -> CheckResult:
        device_id = str(device["device_id"])
        hotspot_id = device.get("metadata", {}).get("hotspot_id") or device.get("hostname")
        keys_raw = os.environ.get("DEPIN_HELIUM_HOTSPOT_KEYS", "[]")

        if dry_run or os.environ.get("IOT_HUB_DRY_RUN", "0") == "1":
            return CheckResult(
                device_id,
                "online",
                latency_ms=5.0,
                message="dry_run",
                metrics={"hotspot_id": hotspot_id, "simulated": True},
            )

        try:
            keys = json.loads(keys_raw) if keys_raw else []
        except json.JSONDecodeError:
            keys = []

        if keys and hotspot_id:
            for entry in keys:
                if isinstance(entry, dict) and entry.get("id") == hotspot_id:
                    status = str(entry.get("status", "configured"))
                    return CheckResult(
                        device_id,
                        "online" if status in ("online", "configured", "active") else "degraded",
                        message=f"helium key registry: {status}",
                        metrics={"hotspot_id": hotspot_id, "source": "env"},
                    )

        if device.get("ip"):
            return IcmpAdapter().check(device, dry_run=dry_run)

        return CheckResult(
            device_id,
            "configured",
            message="hotspot registered; set DEPIN_HELIUM_HOTSPOT_KEYS or device IP for live probe",
            metrics={"hotspot_id": hotspot_id},
        )

from __future__ import annotations

import os
import subprocess
import time
from typing import Any

from .base import CheckResult, DeviceAdapter


class IcmpAdapter(DeviceAdapter):
    device_type = "icmp"

    def check(self, device: dict[str, Any], *, dry_run: bool = False) -> CheckResult:
        device_id = str(device["device_id"])
        ip = device.get("ip")
        if not ip:
            return CheckResult(device_id, "unknown", message="no ip configured")

        if dry_run or os.environ.get("IOT_HUB_DRY_RUN", "0") == "1":
            return CheckResult(
                device_id,
                "online",
                latency_ms=1.0,
                message="dry_run",
                metrics={"ip": ip, "simulated": True},
            )

        timeout_ms = int(os.environ.get("IOT_PING_TIMEOUT_MS", "1500"))
        count = int(os.environ.get("IOT_PING_COUNT", "2"))
        start = time.monotonic()
        try:
            proc = subprocess.run(
                ["ping", "-c", str(count), "-W", str(max(1, timeout_ms // 1000)), ip],
                capture_output=True,
                text=True,
                timeout=max(3, timeout_ms // 500),
            )
            latency = (time.monotonic() - start) * 1000
            if proc.returncode == 0:
                return CheckResult(
                    device_id,
                    "online",
                    latency_ms=round(latency, 2),
                    message="icmp ok",
                    metrics={"ip": ip},
                )
            return CheckResult(
                device_id,
                "offline",
                latency_ms=round(latency, 2),
                message=proc.stderr.strip() or "icmp failed",
                metrics={"ip": ip},
            )
        except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
            return CheckResult(device_id, "offline", message=str(exc), metrics={"ip": ip})

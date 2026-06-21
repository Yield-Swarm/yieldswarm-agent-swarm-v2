from __future__ import annotations

import os
import time
import urllib.error
import urllib.request
from typing import Any

from .base import CheckResult, DeviceAdapter


class HttpPingAdapter(DeviceAdapter):
    device_type = "http_ping"

    def check(self, device: dict[str, Any], *, dry_run: bool = False) -> CheckResult:
        device_id = str(device["device_id"])
        ip = device.get("ip")
        if not ip:
            return CheckResult(device_id, "unknown", message="no ip configured")

        if dry_run or os.environ.get("IOT_HUB_DRY_RUN", "0") == "1":
            return CheckResult(
                device_id,
                "online",
                latency_ms=2.0,
                message="dry_run",
                metrics={"ip": ip, "simulated": True},
            )

        url = f"http://{ip}/"
        start = time.monotonic()
        try:
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=3) as resp:
                latency = (time.monotonic() - start) * 1000
                return CheckResult(
                    device_id,
                    "online",
                    latency_ms=round(latency, 2),
                    message=f"http {resp.status}",
                    metrics={"ip": ip, "http_status": resp.status},
                )
        except urllib.error.HTTPError as exc:
            latency = (time.monotonic() - start) * 1000
            # Router admin pages often return 401/403 when reachable
            if exc.code in (401, 403, 302, 301):
                return CheckResult(
                    device_id,
                    "online",
                    latency_ms=round(latency, 2),
                    message=f"http {exc.code}",
                    metrics={"ip": ip, "http_status": exc.code},
                )
            return CheckResult(device_id, "degraded", latency_ms=round(latency, 2), message=str(exc))
        except Exception as exc:
            return CheckResult(device_id, "offline", message=str(exc), metrics={"ip": ip})

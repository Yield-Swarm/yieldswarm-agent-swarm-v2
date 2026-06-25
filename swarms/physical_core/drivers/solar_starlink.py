"""Solar array + dual Starlink failover monitoring for Carrizozo site."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class SolarStarlinkMonitor:
    """Aggregate 27kW Tesla solar + dual Starlink link health."""

    ARRAY_KW_PEAK = 27.0

    def __init__(self) -> None:
        self.solar_api_url = os.environ.get("TESLA_SOLAR_API_URL", "")
        self.starlink_primary_api = os.environ.get("STARLINK_PRIMARY_API_URL", "")
        self.starlink_failover_api = os.environ.get("STARLINK_FAILOVER_API_URL", "")

    def _fetch_json(self, url: str) -> dict[str, Any] | None:
        if not url:
            return None
        req = urllib.request.Request(url)
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                return json.loads(resp.read().decode())
        except (urllib.error.URLError, json.JSONDecodeError, OSError):
            return None

    def poll_solar(self) -> dict[str, Any]:
        data = self._fetch_json(self.solar_api_url)
        if not data:
            return {
                "arrayKwPeak": self.ARRAY_KW_PEAK,
                "productionKw": 0.0,
                "batterySocPercent": None,
                "gridExportKw": 0.0,
                "status": "offline",
            }
        return {
            "arrayKwPeak": self.ARRAY_KW_PEAK,
            "productionKw": float(data.get("production_kw", 0)),
            "batterySocPercent": data.get("battery_soc_percent"),
            "gridExportKw": float(data.get("grid_export_kw", 0)),
            "status": data.get("status", "producing"),
        }

    def _poll_starlink(self, link_id: str, api_url: str) -> dict[str, Any]:
        data = self._fetch_json(api_url)
        if not data:
            return {"linkId": link_id, "status": "offline"}
        return {
            "linkId": link_id,
            "status": data.get("status", "online"),
            "downlinkMbps": data.get("downlink_mbps"),
            "uplinkMbps": data.get("uplink_mbps"),
            "latencyMs": data.get("latency_ms"),
            "obstructionPercent": data.get("obstruction_percent"),
        }

    def poll_connectivity(self) -> dict[str, Any]:
        primary = self._poll_starlink("starlink-carrizozo-primary", self.starlink_primary_api)
        failover = self._poll_starlink("starlink-carrizozo-failover", self.starlink_failover_api)
        if primary.get("status") == "online":
            active = "primary"
        elif failover.get("status") == "online":
            active = "failover"
        else:
            active = "offline"
        return {"primary": primary, "failover": failover, "activeLink": active}

    def poll(self) -> dict[str, Any]:
        return {"solar": self.poll_solar(), "connectivity": self.poll_connectivity()}

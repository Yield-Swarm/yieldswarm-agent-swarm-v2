"""Carrizozo physical-core telemetry engine — aggregates all SWARM 1 drivers."""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from swarms.physical_core.drivers.solar_starlink import SolarStarlinkMonitor
from swarms.physical_core.drivers.tesla_fleet import TeslaFleetDriver
from swarms.physical_core.drivers.z15_asic_monitor import Z15AsicMonitor


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class PhysicalCoreTelemetryEngine:
    """Single-tick snapshot conforming to schemas/helical/physical-core.v1.json."""

    def __init__(self, site_config_path: Path | None = None) -> None:
        root = Path(__file__).resolve().parents[1]
        self.site_config_path = site_config_path or root / "config" / "carrizozo-site.json"
        with open(self.site_config_path, encoding="utf-8") as f:
            self.site = json.load(f)
        self.solar_starlink = SolarStarlinkMonitor()
        self.asic_monitor = Z15AsicMonitor()
        self.tesla: TeslaFleetDriver | None = None
        if os.environ.get("TESLA_REFRESH_TOKEN"):
            self.tesla = TeslaFleetDriver()

    def _poll_edge_nodes(self) -> dict[str, Any]:
        registry_path = self.site_config_path.parent / "fleet-registry.json"
        with open(registry_path, encoding="utf-8") as f:
            registry = json.load(f)
        nodes = []
        for node in registry.get("edgeNodes", []):
            host = node.get("hostname", "")
            online = False
            if host:
                try:
                    subprocess.run(
                        ["ping", "-c", "1", "-W", "1", host],
                        capture_output=True,
                        check=True,
                        timeout=3,
                    )
                    online = True
                except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
                    online = False
            nodes.append(
                {
                    "nodeId": node["nodeId"],
                    "role": node["role"],
                    "hardware": node["hardware"],
                    "status": "online" if online else "offline",
                    "cpuPercent": None,
                    "memPercent": None,
                    "headlessTerminal": True,
                }
            )
        return {"nodes": nodes}

    def capture_snapshot(self) -> dict[str, Any]:
        power = self.solar_starlink.poll()
        vehicles: list[dict[str, Any]] = []
        if self.tesla:
            try:
                vehicles = self.tesla.poll_fleet()
            except (EnvironmentError, RuntimeError, OSError):
                vehicles = []

        return {
            "schemaVersion": "physical-core/v1",
            "siteId": self.site["siteId"],
            "capturedAt": _utc_now(),
            "solar": power["solar"],
            "connectivity": power["connectivity"],
            "asics": self.asic_monitor.poll_fleet(),
            "vehicles": vehicles,
            "edge": self._poll_edge_nodes(),
        }

    def broadcast_headless(self, snapshot: dict[str, Any]) -> None:
        """Write snapshot for headless Linux terminals / MMORPG ingest."""
        out_dir = Path(os.environ.get("PHYSICAL_CORE_OUT_DIR", ".data/physical-core"))
        out_dir.mkdir(parents=True, exist_ok=True)
        latest = out_dir / "latest.json"
        latest.write_text(json.dumps(snapshot, indent=2), encoding="utf-8")
        ingest_url = os.environ.get("PHYSICAL_CORE_INGEST_URL", "")
        if ingest_url:
            import urllib.request

            req = urllib.request.Request(
                ingest_url,
                data=json.dumps(snapshot).encode(),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            urllib.request.urlopen(req, timeout=10)

    def run_tick(self) -> dict[str, Any]:
        snapshot = self.capture_snapshot()
        self.broadcast_headless(snapshot)
        return snapshot

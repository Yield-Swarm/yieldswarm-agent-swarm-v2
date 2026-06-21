"""Swarm coordinator integration — Nexus bus + sovereign runtime hooks."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
COORDINATOR_STATE = Path(os.environ.get("IOT_COORDINATOR_STATE", REPO_ROOT / ".run" / "iot-coordinator-sync.json"))


class SwarmCoordinatorBridge:
    """Publishes IoT device telemetry to the Nexus messaging bus and sovereign dashboard."""

    def __init__(self):
        self._nexus_bus = None
        self._nexus_registry = None

    def _load_nexus(self) -> None:
        if self._nexus_bus is not None:
            return
        try:
            from services.nexus.messaging import MessagingBus
            from services.nexus.registry import SolenoidRegistry

            self._nexus_bus = MessagingBus()
            self._nexus_registry = SolenoidRegistry()
        except ImportError:
            self._nexus_bus = False  # type: ignore
            self._nexus_registry = False  # type: ignore

    def heartbeat_nexus(self, *, agent_count: int = 0) -> dict[str, Any]:
        self._load_nexus()
        if not self._nexus_registry:
            return {"ok": False, "reason": "nexus unavailable"}
        return self._nexus_registry.heartbeat("iot_hub", agent_count=agent_count)

    def publish_device_status(self, payload: dict[str, Any]) -> dict[str, Any]:
        self._load_nexus()
        if not self._nexus_bus:
            return {"ok": False, "reason": "nexus bus unavailable"}
        msg = self._nexus_bus.publish(
            source="iot_hub",
            target="nexus",
            topic="device_status",
            payload=payload,
        )
        return {"ok": True, "message": msg.to_dict()}

    def publish_device_heartbeat(self, device_id: str, status: str, metrics: dict[str, Any] | None = None) -> dict[str, Any]:
        return self.publish_device_status({
            "device_id": device_id,
            "status": status,
            "network_id": os.environ.get("IOT_NETWORK_ID", "FWA_37KN9S-IoT"),
            "metrics": metrics or {},
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

    def sync_monitor_report(self, report: dict[str, Any]) -> dict[str, Any]:
        """Push full monitor sweep to Nexus and persist coordinator overlay."""
        heartbeat = self.heartbeat_nexus(agent_count=report.get("summary", {}).get("total", 0))
        bus = self.publish_device_status({
            "event": "monitor_sweep",
            "network_id": report.get("network_id"),
            "summary": report.get("summary"),
            "results": report.get("results"),
            "checked_at": report.get("checked_at"),
        })
        overlay = {
            "synced_at": datetime.now(timezone.utc).isoformat(),
            "network_id": report.get("network_id"),
            "healthy_device_ratio": report.get("summary", {}).get("healthy_ratio", 0.0),
            "device_count": report.get("summary", {}).get("total", 0),
            "online_count": report.get("summary", {}).get("online", 0),
            "nexus_heartbeat": heartbeat,
            "bus": bus,
        }
        COORDINATOR_STATE.parent.mkdir(parents=True, exist_ok=True)
        COORDINATOR_STATE.write_text(json.dumps(overlay, indent=2), encoding="utf-8")

        dashboard_state = REPO_ROOT / "dashboard" / "state.json"
        if dashboard_state.is_file():
            try:
                state = json.loads(dashboard_state.read_text(encoding="utf-8"))
                state.setdefault("iot_hub", {}).update(overlay)
                dashboard_state.write_text(json.dumps(state, indent=2), encoding="utf-8")
            except (json.JSONDecodeError, OSError):
                pass

        return overlay

    def register_swarm_agent_for_device(self, device_id: str, shard_id: int = 0) -> dict[str, Any]:
        """Register IoT device as a Nexus agent slot (swarm coordinator mesh)."""
        self._load_nexus()
        if not self._nexus_registry:
            return {"ok": False, "reason": "nexus registry unavailable"}
        try:
            slot = self._nexus_registry.register_agent(device_id, "iot_hub", shard_id)
            return {"ok": True, "agent": slot.__dict__}
        except ValueError as exc:
            return {"ok": False, "error": str(exc)}

    def last_sync(self) -> dict[str, Any] | None:
        if not COORDINATOR_STATE.is_file():
            return None
        return json.loads(COORDINATOR_STATE.read_text(encoding="utf-8"))

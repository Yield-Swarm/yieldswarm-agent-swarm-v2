"""IoT Hub orchestrator — registry, monitor, coordinator bridge."""

from __future__ import annotations

from typing import Any

from .coordinator import SwarmCoordinatorBridge
from .monitor import DeviceMonitor
from .registry import IoTDeviceRegistry


class IoTHubOrchestrator:
    def __init__(self):
        self.registry = IoTDeviceRegistry()
        self.monitor = DeviceMonitor(self.registry)
        self.coordinator = SwarmCoordinatorBridge()

    def status(self) -> dict[str, Any]:
        return {
            "hub": "iot",
            "network_id": self.registry.network_id(),
            "registry": self.registry.summary(),
            "last_coordinator_sync": self.coordinator.last_sync(),
            "dry_run": self.monitor.dry_run,
        }

    def register_network(self) -> dict[str, Any]:
        devices = self.registry.register_catalog()
        swarm_slots: list[dict[str, Any]] = []
        for i, dev in enumerate(devices):
            swarm_slots.append(self.coordinator.register_swarm_agent_for_device(dev.device_id, shard_id=i % 120))
        self.coordinator.heartbeat_nexus(agent_count=len(devices))
        return {
            "network_id": self.registry.network_id(),
            "registered": len(devices),
            "devices": [d.to_dict() for d in devices],
            "swarm_agents": swarm_slots,
        }

    def monitor_and_sync(self) -> dict[str, Any]:
        report = self.monitor.check_all()
        sync = self.coordinator.sync_monitor_report(report)
        return {"monitor": report, "coordinator": sync}

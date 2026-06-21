"""Nexus Chain orchestrator — ties registry, messaging, and multicloud together."""

from __future__ import annotations

from typing import Any

from .messaging import MessagingBus
from .multicloud import MultiCloudManager
from .registry import SolenoidRegistry
from .vault import NexusVaultClient


class NexusOrchestrator:
    def __init__(self):
        self.registry = SolenoidRegistry()
        self.bus = MessagingBus()
        self.multicloud = MultiCloudManager()
        self.vault = NexusVaultClient()

    def status(self) -> dict[str, Any]:
        vault_ok = self.vault.ping()
        return {
            "solenoid": "nexus",
            "registry": self.registry.summary(),
            "multicloud": self.multicloud.status(),
            "vault": vault_ok,
            "bus_queue": str(self.bus.path),
        }

    def dispatch(self, target: str, topic: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        msg = self.bus.publish("nexus", target, topic, payload or {})
        return {"dispatched": True, "message": msg.to_dict()}

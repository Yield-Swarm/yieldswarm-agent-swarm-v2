"""MEGAPOD watch stub — future Tesla distributed compute node adapter."""

from __future__ import annotations

from typing import Any


class MegapodNode:
    """Placeholder for Tesla MEGAPOD modular AI compute at Supercharger sites."""

    NODE_CLASS = "megapod"
    STATUS = "unavailable"

    @classmethod
    def status(cls) -> dict[str, Any]:
        return {
            "node_class": cls.NODE_CLASS,
            "status": cls.STATUS,
            "message": "Awaiting Tesla MEGAPOD compute placement API",
            "docs": "docs/TESLA_FLEET_INTEGRATION.md",
            "integration": "tesla_fleet_telemetry + future megapod placement",
        }

    @classmethod
    def schedule_workload(cls, workload: str, *, dry_run: bool = True) -> dict[str, Any]:
        if dry_run:
            return {
                "ok": True,
                "dry_run": True,
                "node_class": cls.NODE_CLASS,
                "workload": workload,
                "note": "MEGAPOD API not exposed — queued for Rewards Assembler",
            }
        return {
            "ok": False,
            "error": "MEGAPOD compute API unavailable",
            "node_class": cls.NODE_CLASS,
        }

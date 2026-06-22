"""IoT device registry — register and track physical devices on FWA_37KN9S-IoT."""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
NETWORK_CONFIG = REPO_ROOT / "config" / "iot-hub" / "network.yaml"
DEVICES_CONFIG = REPO_ROOT / "config" / "iot-hub" / "devices.yaml"
STATE_PATH = Path(os.environ.get("IOT_REGISTRY_STATE", REPO_ROOT / ".run" / "iot-registry.json"))


@dataclass
class DeviceRecord:
    device_id: str
    name: str
    device_type: str
    network_id: str
    ip: str | None = None
    hostname: str | None = None
    zone: str = "admin"
    status: str = "registered"
    last_seen: str | None = None
    capabilities: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)
    metrics: dict[str, Any] = field(default_factory=dict)
    registered_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class IoTDeviceRegistry:
    def __init__(self):
        self._network = self._load_yaml(NETWORK_CONFIG)
        self._catalog = self._load_yaml(DEVICES_CONFIG)
        self._state = self._load_state()

    @staticmethod
    def _load_yaml(path: Path) -> dict[str, Any]:
        if not path.is_file():
            return {}
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}

    def _load_state(self) -> dict[str, Any]:
        if not STATE_PATH.is_file():
            return {"network_id": self.network_id(), "devices": {}}
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))

    def _persist(self) -> None:
        STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        STATE_PATH.write_text(json.dumps(self._state, indent=2), encoding="utf-8")

    def network_id(self) -> str:
        return str(self._network.get("network_id", "FWA_37KN9S-IoT"))

    def catalog_devices(self) -> list[dict[str, Any]]:
        return list(self._catalog.get("devices", []))

    def register_catalog(self) -> list[DeviceRecord]:
        """Register all devices from devices.yaml onto the IoT network."""
        registered: list[DeviceRecord] = []
        devices_state: dict[str, Any] = self._state.setdefault("devices", {})
        self._state["network_id"] = self.network_id()

        for row in self.catalog_devices():
            device_id = str(row["id"])
            record = DeviceRecord(
                device_id=device_id,
                name=str(row.get("name", device_id)),
                device_type=str(row.get("type", "unknown")),
                network_id=self.network_id(),
                ip=row.get("ip"),
                hostname=row.get("hostname"),
                zone=str(row.get("zone", "admin")),
                status="registered",
                capabilities=list(row.get("capabilities", [])),
                metadata=dict(row.get("metadata", {})),
            )
            existing = devices_state.get(device_id, {})
            if existing.get("registered_at"):
                record.registered_at = existing["registered_at"]
            devices_state[device_id] = record.to_dict()
            registered.append(record)

        self._persist()
        return registered

    def register_device(
        self,
        device_id: str,
        *,
        name: str,
        device_type: str,
        ip: str | None = None,
        hostname: str | None = None,
        zone: str = "admin",
        capabilities: list[str] | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> DeviceRecord:
        devices_state: dict[str, Any] = self._state.setdefault("devices", {})
        if device_id in devices_state:
            raise ValueError(f"device already registered: {device_id}")

        record = DeviceRecord(
            device_id=device_id,
            name=name,
            device_type=device_type,
            network_id=self.network_id(),
            ip=ip,
            hostname=hostname,
            zone=zone,
            capabilities=capabilities or [],
            metadata=metadata or {},
        )
        devices_state[device_id] = record.to_dict()
        self._state["network_id"] = self.network_id()
        self._persist()
        return record

    def list_devices(self) -> list[DeviceRecord]:
        devices_state = self._state.get("devices", {})
        out: list[DeviceRecord] = []
        for row in devices_state.values():
            row.setdefault("metrics", {})
            out.append(DeviceRecord(**row))
        return out

    def get_device(self, device_id: str) -> DeviceRecord | None:
        row = self._state.get("devices", {}).get(device_id)
        if not row:
            return None
        row.setdefault("metrics", {})
        return DeviceRecord(**row)

    def update_status(self, device_id: str, status: str, *, metrics: dict[str, Any] | None = None) -> DeviceRecord:
        devices_state = self._state.setdefault("devices", {})
        row = devices_state.get(device_id)
        if not row:
            raise ValueError(f"device not found: {device_id}")
        row["status"] = status
        row["last_seen"] = datetime.now(timezone.utc).isoformat()
        if metrics:
            row.setdefault("metrics", {}).update(metrics)
        devices_state[device_id] = row
        self._persist()
        return DeviceRecord(**row)

    def summary(self) -> dict[str, Any]:
        devices = self.list_devices()
        by_status: dict[str, int] = {}
        for d in devices:
            by_status[d.status] = by_status.get(d.status, 0) + 1
        return {
            "network_id": self.network_id(),
            "network_name": self._network.get("network_name"),
            "device_count": len(devices),
            "by_status": by_status,
            "devices": [d.to_dict() for d in devices],
            "state_path": str(STATE_PATH),
        }

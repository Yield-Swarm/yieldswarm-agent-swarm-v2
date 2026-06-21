"""Unified IoT device registry — Apple TV, Helium, routers, phones, miners."""

from __future__ import annotations

import json
import os
import time
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]


class DeviceType(str, Enum):
    APPLE_TV = "apple_tv"
    HELIUM = "helium"
    ROUTER = "router"
    PHONE = "phone"
    ANTMINER = "antminer"
    GRASS = "grass"
    FIRE_TV = "fire_tv"
    COMPUTE = "compute"


@dataclass
class IoTDevice:
    id: str
    type: DeviceType
    name: str = ""
    mac: str = ""
    ip: str = ""
    wallet: str = ""
    status: str = "unknown"
    last_seen: float = field(default_factory=time.time)
    meta: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["type"] = self.type.value
        return d

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "IoTDevice":
        data = dict(data)
        data["type"] = DeviceType(data.get("type", "compute"))
        return cls(**{k: v for k, v in data.items() if k in cls.__dataclass_fields__})


class DeviceRegistry:
    """File-backed registry with env bootstrap for Helium + Grass lineups."""

    def __init__(self, path: Optional[Path] = None):
        run_dir = Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))
        self.path = path or (run_dir / "iot" / "devices.json")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self._write({"devices": [], "bootstrapped": False})

    def _read(self) -> Dict[str, Any]:
        try:
            return json.loads(self.path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, FileNotFoundError):
            return {"devices": [], "bootstrapped": False}

    def _write(self, data: Dict[str, Any]) -> None:
        self.path.write_text(json.dumps(data, indent=2), encoding="utf-8")

    def bootstrap_from_env(self) -> int:
        """Import Helium hotspots and Grass lineups from env on first run."""
        data = self._read()
        if data.get("bootstrapped"):
            return 0

        added = 0
        devices = [IoTDevice.from_dict(d) for d in data.get("devices", [])]
        existing_ids = {d.id for d in devices}

        helium_raw = os.environ.get("DEPIN_HELIUM_HOTSPOT_KEYS", "")
        if helium_raw and helium_raw not in ("[]", "[REDACTED]"):
            try:
                hotspots = json.loads(helium_raw)
                if isinstance(hotspots, list):
                    for i, h in enumerate(hotspots):
                        if not isinstance(h, dict):
                            continue
                        dev_id = f"helium-{h.get('serial', i + 1)}"
                        if dev_id in existing_ids:
                            continue
                        devices.append(
                            IoTDevice(
                                id=dev_id,
                                type=DeviceType.HELIUM,
                                name=h.get("ssid") or h.get("model") or dev_id,
                                mac=h.get("mac", ""),
                                wallet=h.get("wallet", ""),
                                status="configured",
                                meta={"model": h.get("model"), "serial": h.get("serial")},
                            )
                        )
                        added += 1
            except json.JSONDecodeError:
                pass

        grass_raw = os.environ.get("GRASS_NODE_KEYS", "") or os.environ.get("GRASS_LINEUPS", "")
        if grass_raw and grass_raw not in ("[]", "[REDACTED]"):
            try:
                lineups = json.loads(grass_raw)
                if isinstance(lineups, list):
                    for item in lineups:
                        if not isinstance(item, dict):
                            continue
                        dev_id = item.get("id") or item.get("device_id") or f"grass-{added}"
                        if dev_id in existing_ids:
                            continue
                        platform = str(item.get("platform", "desktop")).lower()
                        dtype = DeviceType.PHONE if "android" in platform or "ios" in platform else DeviceType.GRASS
                        devices.append(
                            IoTDevice(
                                id=dev_id,
                                type=dtype,
                                name=item.get("id", dev_id),
                                wallet=item.get("wallet", ""),
                                status="configured",
                                meta={"platform": platform, "multiplier": item.get("multiplier")},
                            )
                        )
                        added += 1
            except json.JSONDecodeError:
                pass

        tv_hosts = os.environ.get("IOT_APPLE_TV_HOSTS", "")
        if tv_hosts:
            for i, host in enumerate(tv_hosts.split(",")):
                host = host.strip()
                if not host:
                    continue
                dev_id = f"appletv-{i + 1}"
                if dev_id in existing_ids:
                    continue
                devices.append(
                    IoTDevice(
                        id=dev_id,
                        type=DeviceType.APPLE_TV,
                        name=host,
                        ip=host,
                        status="registered",
                    )
                )
                added += 1

        fire_hosts = os.environ.get("IOT_FIRE_TV_HOSTS", "")
        if fire_hosts:
            for i, host in enumerate(fire_hosts.split(",")):
                host = host.strip()
                if not host:
                    continue
                dev_id = f"firetv-{i + 1}"
                if dev_id in existing_ids:
                    continue
                devices.append(
                    IoTDevice(
                        id=dev_id,
                        type=DeviceType.FIRE_TV,
                        name=host,
                        ip=host,
                        status="registered",
                    )
                )
                added += 1

        self._write({"devices": [d.to_dict() for d in devices], "bootstrapped": True})
        return added

    def list_devices(self, device_type: Optional[DeviceType] = None) -> List[IoTDevice]:
        data = self._read()
        devices = [IoTDevice.from_dict(d) for d in data.get("devices", [])]
        if device_type:
            devices = [d for d in devices if d.type == device_type]
        return devices

    def upsert(self, device: IoTDevice) -> IoTDevice:
        data = self._read()
        devices = [IoTDevice.from_dict(d) for d in data.get("devices", [])]
        device.last_seen = time.time()
        replaced = False
        for i, d in enumerate(devices):
            if d.id == device.id:
                devices[i] = device
                replaced = True
                break
        if not replaced:
            devices.append(device)
        self._write({"devices": [d.to_dict() for d in devices], "bootstrapped": data.get("bootstrapped", True)})
        return device

    def summary(self) -> Dict[str, Any]:
        devices = self.list_devices()
        by_type: Dict[str, int] = {}
        for d in devices:
            by_type[d.type.value] = by_type.get(d.type.value, 0) + 1
        online = sum(1 for d in devices if d.status in ("online", "configured", "registered"))
        return {
            "total": len(devices),
            "online": online,
            "by_type": by_type,
            "devices": [d.to_dict() for d in devices],
        }

from __future__ import annotations

from typing import Any

from .base import DeviceAdapter, CheckResult
from .helium import HeliumHotspotAdapter
from .http_ping import HttpPingAdapter
from .icmp import IcmpAdapter

_TYPE_MAP: dict[str, DeviceAdapter] = {
    "apple_tv": IcmpAdapter(),
    "wifi_extender": IcmpAdapter(),
    "xfinity_router": HttpPingAdapter(),
    "helium_hotspot": HeliumHotspotAdapter(),
    "icmp": IcmpAdapter(),
    "http_ping": HttpPingAdapter(),
}

_CHECK_MAP: dict[str, DeviceAdapter] = {
    "icmp": IcmpAdapter(),
    "http_ping": HttpPingAdapter(),
    "helium_api": HeliumHotspotAdapter(),
}


def get_adapter(device: dict[str, Any]) -> DeviceAdapter:
    check = device.get("check")
    if check and check in _CHECK_MAP:
        return _CHECK_MAP[check]
    device_type = device.get("device_type") or device.get("type", "unknown")
    return _TYPE_MAP.get(str(device_type), IcmpAdapter())

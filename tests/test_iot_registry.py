"""Tests for IoT device registry."""

from services.iot.device_registry import DeviceRegistry, DeviceType, IoTDevice


def test_registry_upsert_and_summary():
    reg = DeviceRegistry()
    reg.upsert(IoTDevice(id="test-router", type=DeviceType.ROUTER, name="HQ Router", status="online"))
    summary = reg.summary()
    assert summary["total"] >= 1
    assert "router" in summary["by_type"]


def test_bootstrap_idempotent():
    reg = DeviceRegistry()
    first = reg.bootstrap_from_env()
    second = reg.bootstrap_from_env()
    assert second == 0
    assert first >= 0

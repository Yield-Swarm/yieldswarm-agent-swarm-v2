#!/usr/bin/env python3
"""Local smoke test for Physical Control Center (no hardware required)."""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))

from services.control_center.encrypted_id import mint_pow_id
from services.control_center.models import DeviceStatsIn, DeviceStatus
from services.control_center.state import state


async def run() -> None:
    from services.control_center.main import ingest_device_stats

    payload = DeviceStatsIn(
        device_id="test-edge-laptop",
        cpu_percent=42.5,
        memory_percent=61.0,
        network_ok=True,
        hash_rate_mhs=12.3,
        latency_ms=8.5,
        kind="edge-worker",
    )
    result = await ingest_device_stats(payload)
    snap = await state.snapshot()
    print("ingest:", json.dumps(result, indent=2))
    print("snapshot devices:", snap.device_count)
    print("encrypted sample:", mint_pow_id("test-edge-laptop")[:32] + "…")
    assert snap.device_count >= 1
    assert result["accepted"] is True
    print("control-center local test OK")


if __name__ == "__main__":
    asyncio.run(run())

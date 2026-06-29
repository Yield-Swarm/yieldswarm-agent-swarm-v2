"""Background hardware aggregation — ping, HTTP status, mining JSON-RPC stubs."""

from __future__ import annotations

import asyncio
import json
import logging
import platform
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional
from urllib.parse import urlparse

import httpx
import yaml

from services.control_center.config import (
    CONFIG_PATH,
    HTTP_TIMEOUT_SEC,
    PING_TIMEOUT_SEC,
    POLL_INTERVAL_SEC,
)
from services.control_center.encrypted_id import mint_pow_id, mint_powui_id
from services.control_center.models import DeviceRecord, DeviceStatus
from services.control_center.state import state

log = logging.getLogger("control_center.aggregator")


def load_device_config() -> list[dict[str, Any]]:
    if not CONFIG_PATH.exists():
        return []
    data = yaml.safe_load(CONFIG_PATH.read_text()) or {}
    return list(data.get("devices", []))


async def icmp_ping(host: str, timeout: float = PING_TIMEOUT_SEC) -> tuple[bool, Optional[float]]:
    """Return (reachable, latency_ms). Uses system ping — non-blocking via executor."""
    if not host:
        return False, None

    param = "-n" if platform.system().lower() == "windows" else "-c"
    wait = "-w" if platform.system().lower() == "windows" else "-W"
    wait_val = str(int(timeout * 1000)) if platform.system().lower() == "windows" else str(int(timeout))

    ping_bin = shutil.which("ping")
    if not ping_bin:
        return False, None

    cmd = [ping_bin, param, "1", wait, wait_val, host]

    def _run() -> tuple[bool, Optional[float]]:
        import subprocess

        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 1)
            ok = proc.returncode == 0
            latency = None
            if ok:
                for token in proc.stdout.replace("=", " ").replace("<", " ").split():
                    if token.replace(".", "", 1).isdigit():
                        try:
                            latency = float(token)
                            break
                        except ValueError:
                            continue
            return ok, latency
        except (subprocess.TimeoutExpired, OSError):
            return False, None

    return await asyncio.get_running_loop().run_in_executor(None, _run)


async def fetch_status_url(url: str) -> dict[str, Any]:
    async with httpx.AsyncClient(timeout=HTTP_TIMEOUT_SEC) as client:
        res = await client.get(url)
        res.raise_for_status()
        return res.json()


async def poll_device(device: dict[str, Any]) -> None:
    device_id = device["id"]
    kind = device.get("kind", "miner")
    host = device.get("host")
    status_url = device.get("status_url")
    started = time.perf_counter()

    try:
        latency_ms: Optional[float] = None
        hash_rate: Optional[float] = None
        temp_c: Optional[float] = None
        cpu_pct: Optional[float] = None
        mem_pct: Optional[float] = None
        online = False

        if status_url:
            data = await fetch_status_url(status_url)
            online = True
            latency_ms = round((time.perf_counter() - started) * 1000, 2)
            hash_rate = _extract_float(data, ["hash_rate_mhs", "hashrate", "hash_rate", "mhs"])
            temp_c = _extract_float(data, ["temp_c", "temperature", "temp"])
            cpu_pct = _extract_float(data, ["cpu_percent", "cpu"])
            mem_pct = _extract_float(data, ["memory_percent", "mem"])
        elif host:
            online, latency_ms = await icmp_ping(host)
        else:
            raise ValueError("device needs host or status_url")

        if not online and not status_url:
            await state.mark_offline(device_id, "ICMP unreachable")
            return

        raw = device_id
        record = DeviceRecord(
            device_id=device_id,
            kind=kind,
            host=host or urlparse(status_url).hostname if status_url else host,
            status=DeviceStatus.ONLINE if online else DeviceStatus.DEGRADED,
            hash_rate_mhs=hash_rate or device.get("sim_hash_rate_mhs"),
            latency_ms=latency_ms,
            cpu_percent=cpu_pct,
            memory_percent=mem_pct,
            temp_c=temp_c,
            encrypted_pow_id=mint_pow_id(raw, {"kind": kind}),
            encrypted_powui_id=mint_powui_id(raw, {"surface": "control-center"}),
            last_seen_at=datetime.now(timezone.utc).isoformat(),
            source="poller",
        )
        await state.upsert(record)
    except Exception as exc:  # noqa: BLE001 — per-device isolation
        log.warning("device %s offline: %s", device_id, exc)
        await state.mark_offline(device_id, str(exc))


def _extract_float(data: dict[str, Any], keys: list[str]) -> Optional[float]:
    for key in keys:
        if key in data and data[key] is not None:
            try:
                return float(data[key])
            except (TypeError, ValueError):
                continue
    return None


async def poll_all_devices() -> None:
    devices = load_device_config()
    if not devices:
        log.debug("no devices in %s", CONFIG_PATH)
        return
    await asyncio.gather(*(poll_device(d) for d in devices), return_exceptions=True)


async def aggregation_loop(stop_event: asyncio.Event) -> None:
    log.info("aggregation loop started interval=%ss", POLL_INTERVAL_SEC)
    while not stop_event.is_set():
        try:
            await poll_all_devices()
        except Exception:
            log.exception("aggregation tick failed — continuing")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=POLL_INTERVAL_SEC)
        except asyncio.TimeoutError:
            continue
    log.info("aggregation loop stopped")

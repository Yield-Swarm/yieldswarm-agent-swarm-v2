"""Mandelbrot / Tree of Life routing for Kairo telemetry (Python mirror of TS lib)."""

from __future__ import annotations

import json
from typing import Any, Dict

TREE_BRANCHES = 7
TREE_TRIBES = 12
CRON_SHARDS = 120


def _simple_hash(s: str) -> int:
    h = 0
    for c in s:
        h = (31 * h + ord(c)) & 0xFFFFFFFF
    return abs(h)


def mandelbrot_iteration(lat: float, lng: float, max_iter: int = 64) -> Dict[str, Any]:
    real = (lng + 180) / 360 * 3.5 - 2.5
    imaginary = (lat + 90) / 180 * 3.0 - 1.5
    zr = zi = 0.0
    iteration = 0
    escaped = False
    while iteration < max_iter:
        zr2, zi2 = zr * zr, zi * zi
        if zr2 + zi2 > 4:
            escaped = True
            break
        zr, zi = zr2 - zi2 + real, 2 * zr * zi + imaginary
        iteration += 1
    return {"real": real, "imaginary": imaginary, "iteration": iteration, "escaped": escaped}


def route_event(event: Dict[str, Any]) -> Dict[str, int]:
    payload = event.get("payload", {})
    lat = float(payload.get("lat", payload.get("latitude", 0)))
    lng = float(payload.get("lng", payload.get("longitude", 0)))

    if lat != 0 or lng != 0:
        coord = mandelbrot_iteration(lat, lng)
    else:
        h = _simple_hash(f"{event.get('driverId')}:{event.get('timestamp')}")
        coord = {
            "real": (h % 1000) / 1000,
            "imaginary": ((h >> 10) % 1000) / 1000,
            "iteration": h % 64,
        }

    branch = coord["iteration"] % TREE_BRANCHES
    tribe = int(coord["real"] * 100) % TREE_TRIBES
    cron_shard = int(coord["imaginary"] * 100) % CRON_SHARDS
    agent_index = _simple_hash(event.get("driverId", "")) % 84
    global_index = branch * (TREE_TRIBES * CRON_SHARDS) + tribe * CRON_SHARDS + cron_shard

    return {
        "branch": branch,
        "tribe": tribe,
        "cron_shard": cron_shard,
        "agent_index": agent_index,
        "global_index": global_index,
    }

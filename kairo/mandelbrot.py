"""Route signed telemetry into Mandelbrot / Tree of Life shards."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Any

CRON_SHARD_COUNT = 120
AGENTS_PER_SHARD = 84

TREE_NODES = (
    "kether", "chokmah", "binah", "chesed", "geburah",
    "tiphereth", "netzach", "hod", "yesod", "malkuth",
)


@dataclass
class MandelbrotRoute:
    mandelbrot_shard: int
    tree_of_life_node: str
    agent_range_start: int
    agent_range_end: int
    cron_shard_id: int


def driver_shard_index(driver_id: str, shard_count: int = CRON_SHARD_COUNT) -> int:
    digest = hashlib.sha256(driver_id.encode()).digest()
    return int.from_bytes(digest[:4], "big") % shard_count


def classify_tree_node(payload: dict[str, Any]) -> str:
    speed = float(payload.get("speedMph", 0))
    distance = float(payload.get("distanceMiles", 0))
    if speed < 1:
        return "malkuth"
    if speed < 15:
        return "yesod"
    if speed < 35:
        return "hod"
    if speed < 55:
        return "netzach"
    if distance > 50:
        return "chokmah"
    if distance > 20:
        return "binah"
    return "tiphereth"


def route_telemetry(driver_id: str, payload: dict[str, Any]) -> MandelbrotRoute:
    cron_shard = driver_shard_index(driver_id)
    speed = float(payload.get("speedMph", 0))
    mandelbrot_shard = (cron_shard + int(speed)) % CRON_SHARD_COUNT
    start = cron_shard * AGENTS_PER_SHARD
    return MandelbrotRoute(
        mandelbrot_shard=mandelbrot_shard,
        tree_of_life_node=classify_tree_node(payload),
        agent_range_start=start,
        agent_range_end=start + AGENTS_PER_SHARD - 1,
        cron_shard_id=cron_shard,
    )


def estimate_depin_rewards(telemetry_count: int, total_distance: float) -> str:
    return f"{telemetry_count * 0.001 + total_distance * 0.05:.4f}"


def upsert_contribution(
    existing: dict[str, Any] | None,
    driver_id: str,
    *,
    telemetry_count: int = 0,
    distance_miles: float = 0.0,
    app_revenue: float = 0.0,
) -> dict[str, Any]:
    prev_count = int((existing or {}).get("telemetryCount", 0))
    prev_dist = float((existing or {}).get("totalDistanceMiles", 0))
    prev_rev = float((existing or {}).get("appRevenueShare", 0))
    total_count = prev_count + telemetry_count
    total_dist = prev_dist + distance_miles
    total_rev = prev_rev + app_revenue
    return {
        "driverId": driver_id,
        "telemetryCount": total_count,
        "totalDistanceMiles": total_dist,
        "estimatedDepinRewards": estimate_depin_rewards(total_count, total_dist),
        "appRevenueShare": f"{total_rev:.2f}",
    }

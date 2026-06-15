"""Mandelbrot / Tree of Life data routing for Kairo telemetry."""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from typing import Any, Iterable, List, Optional

from kairo.models.telemetry import TelemetryEvent, telemetry_hash


@dataclass(frozen=True)
class MandelbrotNode:
    """A node in the Tree of Life architecture."""

    shard_id: int
    iteration: int
    escaped: bool
    reward_weight: float
    telemetry_hash: str


def _mandelbrot_escape(cx: float, cy: float, max_iter: int = 32) -> tuple[int, bool]:
    x, y = 0.0, 0.0
    for i in range(max_iter):
        x2 = x * x - y * y + cx
        y = 2 * x * y + cy
        x = x2
        if x * x + y * y > 4:
            return i, True
    return max_iter, False


def hash_to_coords(telemetry_hash: str) -> tuple[float, float]:
    """Map a telemetry hash to Mandelbrot plane coordinates."""
    h = telemetry_hash
    cx = (int(h[0:8], 16) / 0xFFFFFFFF) * 3.0 - 2.0
    cy = (int(h[8:16], 16) / 0xFFFFFFFF) * 2.5 - 1.25
    return cx, cy


def route_telemetry(event: TelemetryEvent, *, shard_count: int = 120) -> MandelbrotNode:
    """Route signed telemetry into a Mandelbrot shard for agent processing."""
    th = telemetry_hash(event)
    cx, cy = hash_to_coords(th)
    iteration, escaped = _mandelbrot_escape(cx, cy)

    shard_id = int(th[:4], 16) % shard_count
    reward_weight = 1.0 + (iteration / 32.0) * (2.0 if escaped else 0.5)

    return MandelbrotNode(
        shard_id=shard_id,
        iteration=iteration,
        escaped=escaped,
        reward_weight=reward_weight,
        telemetry_hash=th,
    )


def batch_route(events: Iterable[TelemetryEvent], shard_count: int = 120) -> List[dict[str, Any]]:
    """Route a batch of telemetry events; returns JSON-serializable records."""
    results = []
    for event in events:
        node = route_telemetry(event, shard_count=shard_count)
        results.append({
            "event": event.canonical_payload(),
            "node": {
                "shard_id": node.shard_id,
                "iteration": node.iteration,
                "escaped": node.escaped,
                "reward_weight": node.reward_weight,
                "telemetry_hash": node.telemetry_hash,
            },
        })
    return results


def tree_of_life_projection(shard_totals: dict[int, float]) -> dict[str, Any]:
    """Aggregate shard weights into Tree of Life branches (10 sephirot × 12 paths)."""
    branches = {f"sephira_{i}": 0.0 for i in range(1, 11)}
    total = sum(shard_totals.values()) or 1.0

    for shard_id, weight in shard_totals.items():
        sephira = (shard_id % 10) + 1
        branches[f"sephira_{sephira}"] += weight

    normalized = {k: round(v / total, 6) for k, v in branches.items()}
    harmony = 1.0 - (max(normalized.values()) - min(normalized.values()))

    return {
        "branches": normalized,
        "harmony_index": round(harmony, 4),
        "total_weight": round(total, 4),
    }

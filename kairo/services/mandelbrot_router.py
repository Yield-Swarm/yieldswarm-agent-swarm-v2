"""Mandelbrot fractal sharding + Tree of Life routing for YieldSwarm."""

from __future__ import annotations

import hashlib

from kairo.config import settings
from kairo.models.schemas import MandelbrotRouteOut

# Kabbalistic Tree of Life — 10 sephirot (YieldSwarm data routing nodes)
SEPHIROT = [
    "Kether",      # Crown — ingress
    "Chokmah",     # Wisdom — velocity analytics
    "Binah",       # Understanding — route compression
    "Chesed",      # Mercy — reward amplification
    "Geburah",     # Strength — fraud rejection
    "Tiphareth",   # Beauty — balance / 2x pay gate
    "Netzach",     # Victory — DePIN HNT
    "Hod",         # Splendor — DePIN GRASS
    "Yesod",       # Foundation — persistence
    "Malkuth",     # Kingdom — payout settlement
]

# YieldSwarm sharding formula factors (from architecture docs)
SHARD_FACTORS = [1, 3, 5, 11, 1111, 1, 3, 8, 9, 11]


def mandelbrot_escape_iterations(lat: float, lon: float, max_iter: int | None = None) -> int:
    """Map GPS coordinates into Mandelbrot set escape time → shard index."""
    max_iter = max_iter or settings.mandelbrot_max_iter
    # Scale GPS to complex plane near Mandelbrot boundary
    scale = 0.01
    c = complex((lat - 37.7749) * scale, (lon + 122.4194) * scale)
    z = 0j
    for i in range(max_iter):
        z = z * z + c
        if abs(z) > 2.0:
            return i
    return max_iter


def shard_from_mandelbrot(lat: float, lon: float) -> int:
    escape = mandelbrot_escape_iterations(lat, lon)
    product = 1
    for f in SHARD_FACTORS:
        product = (product * f) % settings.yieldswarm_shard_count
    shard = (escape * product + int(abs(lat * 100) + abs(lon * 100))) % settings.yieldswarm_shard_count
    return shard


def tree_of_life_node(payload_hash: str) -> str:
    idx = int(payload_hash[:8], 16) % len(SEPHIROT)
    return SEPHIROT[idx]


def helix_path(shard_id: int, tree_node: str) -> str:
    """Helix Chain cross-execution path identifier."""
    digest = hashlib.sha256(f"{shard_id}:{tree_node}".encode()).hexdigest()[:16]
    return f"helix://yieldswarm/shard/{shard_id}/sephira/{tree_node}/{digest}"


def cron_slot(shard_id: int) -> int:
    return shard_id % 120


def route_telemetry(lat: float, lon: float, payload_hash: str) -> MandelbrotRouteOut:
    shard = shard_from_mandelbrot(lat, lon)
    node = tree_of_life_node(payload_hash)
    return MandelbrotRouteOut(
        shard_id=shard,
        tree_of_life_node=node,
        helix_path=helix_path(shard, node),
        yieldswarm_cron_slot=cron_slot(shard),
    )

"""
Mandelbrot PoW scoring for Tree of Life shard routing.

Maps driver telemetry coordinates into a Mandelbrot escape-time score,
then routes to one of 120 cron shards (Tree of Life branches).
"""

from __future__ import annotations

SHARD_COUNT = 120


def compute_mandelbrot_score(lat: float, lon: float, speed_mph: float) -> float:
    """
    Lightweight Mandelbrot-inspired score from geo + speed.
    Higher scores = more "interesting" telemetry for emission weighting.
    """
    c_re = (lon % 3.0) - 1.5
    c_im = (lat % 3.0) - 1.5
    z_re, z_im = 0.0, 0.0
    iterations = 0
    max_iter = 64
    while z_re * z_re + z_im * z_im <= 4.0 and iterations < max_iter:
        z_re, z_im = z_re * z_re - z_im * z_im + c_re, 2 * z_re * z_im + c_im
        iterations += 1
    base = iterations / max_iter
    speed_factor = min(speed_mph / 65.0, 1.0)
    return round(base * (0.7 + 0.3 * speed_factor), 6)


def shard_for_score(score: float) -> str:
    """Route to Tree of Life shard (0..119) based on Mandelbrot score."""
    idx = int(score * SHARD_COUNT) % SHARD_COUNT
    return f"tol-shard-{idx:03d}"

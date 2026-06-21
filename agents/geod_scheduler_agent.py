#!/usr/bin/env python3
"""GEOD scheduler agent — sovereign loop + Odysseus post-init hook target."""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from services.geod.scheduler import run_geod_tick  # noqa: E402


def tick() -> None:
    report = run_geod_tick()
    coord = report.get("coordinate", {})
    print(
        f"[geod] shard={coord.get('shard_id')} "
        f"phase={coord.get('entropy_phase')} "
        f"weight={coord.get('mandelbrot_weight')}"
    )


def main() -> int:
    tick()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

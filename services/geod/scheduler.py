"""Geospatial-Entropy Distributed (GEOD) scheduler tick.

Hooks into Odysseus workspace post-init via odysseus-workspace GEOD cron.
Harvests entropy shard coordinates for Mandelbrot / Tree-of-Life routing.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict

REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_dir() -> Path:
    return Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))


def compute_entropy_coordinate(shard_id: int, shard_count: int) -> Dict[str, Any]:
    """Deterministic geospatial-entropy coordinate for a shard."""
    t = time.time()
    phase = (t % 86400) / 86400.0
    return {
        "shard_id": shard_id,
        "shard_count": shard_count,
        "entropy_phase": round(phase, 6),
        "mandelbrot_weight": round((shard_id + 1) / max(shard_count, 1), 6),
        "ts": int(t),
    }


def run_geod_tick() -> Dict[str, Any]:
    shard_count = int(os.environ.get("GEOD_ENTROPY_SHARD_COUNT", "120"))
    agent_shard = int(os.environ.get("AGENT_SHARD_ID", "0"))
    coord = compute_entropy_coordinate(agent_shard, shard_count)

    out_dir = _run_dir() / "geod"
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / "last-tick.json"
    path.write_text(json.dumps(coord, indent=2), encoding="utf-8")

    return {
        "ok": True,
        "coordinate": coord,
        "state_path": str(path),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="GEOD scheduler tick")
    parser.add_argument("--tick", action="store_true", help="Run one GEOD tick")
    args = parser.parse_args()
    if not args.tick:
        parser.print_help()
        return 1
    report = run_geod_tick()
    print(json.dumps(report))
    return 0 if report.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

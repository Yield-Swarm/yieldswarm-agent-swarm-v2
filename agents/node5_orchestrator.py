#!/usr/bin/env python3
"""Node 5 agent — PyHackathon Stellar + Cosmos SDK tick.

Invoked by deploy/runtime/swarm_runner.py on each sovereign loop cycle.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from nodes.node5.orchestrator import run_cycle  # noqa: E402


def tick() -> None:
    run_dir = Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))
    report = run_cycle(run_dir=run_dir)
    status = "ok" if report.get("ok") else "error"
    print(f"[node5] cycle {status} dry_run={report.get('dry_run')} actions={list(report.get('results', {}))}")


def main() -> int:
    tick()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

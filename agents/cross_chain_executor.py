#!/usr/bin/env python3
"""Cross-chain execution agent — runs on each Sovereign Loop tick.

Invoked by deploy/runtime/swarm_runner.py alongside Akash optimizer and
treasury agents. Persists receipts to .run/cross-chain-*.json for Arena.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from services.cross_chain.executor import run_scheduled_strategies  # noqa: E402


def tick() -> None:
    shard = int(os.getenv("AGENT_SHARD_ID", "0"))
    summary = run_scheduled_strategies(shard_id=shard)
    print(f"[cross-chain] shard={shard} jobs={summary.get('job_count')} dry_run={summary.get('dry_run')}")
    totals = summary.get("treasury_totals_usd", {})
    if totals:
        print(f"[cross-chain] treasury routing (USD): {json.dumps(totals)}")


def main() -> int:
    tick()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Rewards CLI — reshard, assemble, sweep."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from services.rewards.orchestrator import RewardsOrchestrator


def main() -> int:
    p = argparse.ArgumentParser(description="YieldSwarm rewards — reshard / assemble / sweep")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    sub.add_parser("reshard")
    sub.add_parser("assemble")
    sub.add_parser("sweep")
    sub.add_parser("full")

    args = p.parse_args()
    orch = RewardsOrchestrator()

    if args.cmd == "status":
        print(json.dumps(orch.status()))
    elif args.cmd == "reshard":
        print(json.dumps(orch.resharder.reshard()))
    elif args.cmd == "assemble":
        print(json.dumps(orch.assembler.assemble()))
    elif args.cmd == "sweep":
        print(json.dumps(orch.sweeper.sweep()))
    elif args.cmd == "full":
        print(json.dumps(orch.run_full()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

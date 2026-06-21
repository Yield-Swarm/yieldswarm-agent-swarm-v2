#!/usr/bin/env python3
"""Akash GPU bid optimizer — dynamic uakt bidding for H100 / A100 fleets.

Termux / Pixel:
    python akash/bid-optimizer.py --gpu h100 --target-apr 40 --max-bid 85000 --auto

Writes recommendation to .run/akash-bid-optimize.json when --auto is set.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
RUN_DIR = Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))


@dataclass
class BidRecommendation:
    gpu: str
    target_apr_pct: float
    max_bid_uakt: int
    recommended_bid_uakt: int
    miner_priority: str
    backend_priority: str
    live: bool
    timestamp: str
    notes: str


def _have_akash() -> bool:
    return shutil.which("akash") is not None


def _query_bids(gpu: str) -> list[dict]:
    """Best-effort live bid snapshot from akash CLI."""
    if not _have_akash():
        return []
    try:
        out = subprocess.check_output(
            ["akash", "query", "market", "bid", "list", "--output", "json"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=30,
        )
        data = json.loads(out)
        bids = data.get("bids", data) if isinstance(data, dict) else data
        if not isinstance(bids, list):
            return []
        return [b for b in bids if gpu.lower() in json.dumps(b).lower()]
    except (subprocess.CalledProcessError, json.JSONDecodeError, subprocess.TimeoutExpired):
        return []


def optimize_bid(
    gpu: str,
    target_apr: float,
    max_bid: int,
) -> BidRecommendation:
    """Balance H100 miner priority vs efficient backend leases."""
    live_bids = _query_bids(gpu)
    live = bool(live_bids)

    # Dynamic scale: target 40% APR → bid at 85% of max when simulated;
    # tighten when live bids are sparse.
    if live and len(live_bids) < 3:
        recommended = int(max_bid * 0.92)
        notes = f"sparse {gpu} market — bid +7% above baseline"
    elif live:
        recommended = int(max_bid * 0.85)
        notes = f"balanced bidding across {len(live_bids)} live {gpu} bids"
    else:
        recommended = int(max_bid * 0.85)
        notes = "simulated — akash CLI offline; using 85k uakt balanced default"

    # Miner H100 priority, backend efficient (lower bid tier)
    miner_priority = "high" if gpu.lower() == "h100" else "medium"
    backend_priority = "efficient"

    return BidRecommendation(
        gpu=gpu.upper(),
        target_apr_pct=target_apr,
        max_bid_uakt=max_bid,
        recommended_bid_uakt=recommended,
        miner_priority=miner_priority,
        backend_priority=backend_priority,
        live=live,
        timestamp=datetime.now(timezone.utc).isoformat(),
        notes=notes,
    )


def main() -> int:
    p = argparse.ArgumentParser(description="Akash GPU bid optimizer")
    p.add_argument("--gpu", default="h100", help="GPU model filter (h100, a100, rtx4090)")
    p.add_argument("--target-apr", type=float, default=40.0, help="target APR percent")
    p.add_argument("--max-bid", type=int, default=85000, help="max bid in uakt")
    p.add_argument("--auto", action="store_true", help="write .run/akash-bid-optimize.json")
    p.add_argument("--json", action="store_true", help="print JSON only")
    args = p.parse_args()

    rec = optimize_bid(args.gpu, args.target_apr, args.max_bid)
    payload = asdict(rec)

    if args.auto:
        RUN_DIR.mkdir(parents=True, exist_ok=True)
        out = RUN_DIR / "akash-bid-optimize.json"
        out.write_text(json.dumps(payload, indent=2) + "\n")

    if args.json or args.auto:
        print(json.dumps(payload, indent=2))
    else:
        print(f"GPU {rec.gpu} | bid {rec.recommended_bid_uakt} uakt (max {rec.max_bid_uakt})")
        print(f"  target APR {rec.target_apr_pct}% | miner={rec.miner_priority} backend={rec.backend_priority}")
        print(f"  live={rec.live} — {rec.notes}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

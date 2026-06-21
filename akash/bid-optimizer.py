#!/usr/bin/env python3
"""Akash GPU bid optimizer — dynamic uakt/block tuning for H100 / RTX fleets.

Balances target APR against max bid ceiling. Writes recommendations to
akash/telemetry/bid-state.json and optionally updates env for deploy scripts.

Usage:
    python3 akash/bid-optimizer.py --gpu h100 --target-apr 40 --max-bid 85000 --auto
    python3 akash/bid-optimizer.py --dry-run
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

SCRIPT_DIR = Path(__file__).resolve().parent
STATE_PATH = SCRIPT_DIR / "telemetry" / "bid-state.json"

# Reference uakt/block bands (tune per market conditions)
GPU_BID_DEFAULTS = {
    "h100": {"min_bid": 55_000, "max_bid": 95_000, "target_bid": 85_000},
    "rtx3090": {"min_bid": 8_000, "max_bid": 25_000, "target_bid": 15_000},
    "rtx5090": {"min_bid": 20_000, "max_bid": 45_000, "target_bid": 32_000},
}


@dataclass
class BidRecommendation:
    gpu: str
    target_apr_pct: float
    recommended_bid_uakt: int
    max_bid_uakt: int
    auto_applied: bool
    akash_cli_available: bool
    lease_count: int
    timestamp: str

    def to_dict(self) -> dict:
        return asdict(self)


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _akash_available() -> bool:
    return shutil.which("akash") is not None


def _lease_count() -> int:
    if not _akash_available():
        return 0
    try:
        out = subprocess.run(
            ["akash", "query", "market", "lease", "list", "--output", "json"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if out.returncode != 0:
            return 0
        data = json.loads(out.stdout or "{}")
        leases = data.get("leases") or data.get("Leases") or []
        if isinstance(leases, list):
            return len(leases)
        return 0
    except Exception:
        return 0


def compute_bid(gpu: str, target_apr: float, max_bid: int) -> int:
    """APR-aware bid: higher target APR → lower bid; capped at max_bid."""
    defaults = GPU_BID_DEFAULTS.get(gpu.lower(), GPU_BID_DEFAULTS["h100"])
    base = defaults["target_bid"]
    # Scale: 40% APR target = base; each +10% APR → -5% bid
    apr_delta = (40.0 - target_apr) / 10.0
    adjusted = int(base * (1.0 + apr_delta * 0.05))
    adjusted = max(defaults["min_bid"], min(adjusted, max_bid, defaults["max_bid"]))
    return adjusted


def apply_bid_env(bid: int) -> bool:
    """Export AKASH_MAX_BID_PRICE for child deploy processes."""
    os.environ["AKASH_MAX_BID_PRICE"] = str(bid)
    env_example = SCRIPT_DIR / "akash-lease-manager.env.example"
    if not env_example.exists():
        return False
    local_env = SCRIPT_DIR / ".env.bid-optimizer"
    lines = []
    if local_env.exists():
        lines = local_env.read_text().splitlines()
    updated = False
    new_lines = []
    for line in lines:
        if line.startswith("AKASH_MAX_BID_PRICE="):
            new_lines.append(f"AKASH_MAX_BID_PRICE={bid}")
            updated = True
        else:
            new_lines.append(line)
    if not updated:
        new_lines.append(f"AKASH_MAX_BID_PRICE={bid}")
    local_env.write_text("\n".join(new_lines) + "\n")
    return True


def main() -> int:
    p = argparse.ArgumentParser(description="Akash GPU bid optimizer")
    p.add_argument("--gpu", default="h100", choices=list(GPU_BID_DEFAULTS.keys()))
    p.add_argument("--target-apr", type=float, default=40.0, help="target APR percent")
    p.add_argument("--max-bid", type=int, default=85_000, help="max uakt per block")
    p.add_argument("--auto", action="store_true", help="write bid to akash/.env.bid-optimizer")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    bid = compute_bid(args.gpu, args.target_apr, args.max_bid)
    leases = _lease_count()
    applied = False
    if args.auto and not args.dry_run:
        applied = apply_bid_env(bid)

    rec = BidRecommendation(
        gpu=args.gpu,
        target_apr_pct=args.target_apr,
        recommended_bid_uakt=bid,
        max_bid_uakt=args.max_bid,
        auto_applied=applied,
        akash_cli_available=_akash_available(),
        lease_count=leases,
        timestamp=_utc_now(),
    )

    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not args.dry_run:
        STATE_PATH.write_text(json.dumps(rec.to_dict(), indent=2) + "\n")

    print(json.dumps(rec.to_dict(), indent=2))
    print(
        f"\nBid tune: {args.gpu} @ {bid} uakt/block "
        f"(target APR {args.target_apr}%, leases={leases})",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

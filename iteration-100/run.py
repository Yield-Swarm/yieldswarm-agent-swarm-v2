#!/usr/bin/env python3
"""Entrypoint for the Iteration 100 sovereign core loop.

Examples
--------
Fast backtest toward the $5M vault, writing dashboard/state.json:

    python3 run.py --ticks 3000

Live-ish daemon (one tick per real second):

    python3 run.py --ticks 100000 --interval 1
"""

from __future__ import annotations

import argparse

from sovereign_core import CoreConfig, SovereignCore
from core.state import load


def print_status(state_path: str) -> None:
    """Print sovereign core status as JSON (for Pixel / monitor scripts)."""
    import json

    state = load(state_path)
    if state is None:
        print(json.dumps({"status": "no_state", "path": state_path}))
        return
    print(
        json.dumps(
            {
                "status": "ok",
                "tick": state.tick,
                "vault_usd": round(state.vault_usd, 2),
                "vault_target_usd": state.vault_target_usd,
                "net_worth_usd": round(state.net_worth_usd, 2),
                "blended_apy": round(state.blended_apy, 4),
                "progress": round(state.progress, 6),
                "workers": len(state.workers),
                "agents": len(state.agents),
                "target_apy": state.target_apy,
            },
            indent=2,
        )
    )


def main() -> None:
    defaults = CoreConfig()
    p = argparse.ArgumentParser(description="YieldSwarm Iteration 100 sovereign core")
    p.add_argument("--ticks", type=int, default=1200, help="number of daily ticks")
    p.add_argument("--interval", type=float, default=0.0, help="seconds to sleep per tick")
    p.add_argument("--seed-workers", type=int, default=defaults.seed_workers)
    p.add_argument("--seed-agents", type=int, default=defaults.seed_agents)
    p.add_argument("--seed-treasury", type=float, default=defaults.seed_treasury_usd)
    p.add_argument("--seed-vault", type=float, default=defaults.seed_vault_usd)
    p.add_argument("--target-apy", type=float, default=defaults.target_apy)
    p.add_argument("--quiet", action="store_true")
    p.add_argument("--status", action="store_true", help="print dashboard state JSON and exit")
    args = p.parse_args()

    cfg = CoreConfig(
        seed_workers=args.seed_workers,
        seed_agents=args.seed_agents,
        seed_treasury_usd=args.seed_treasury,
        seed_vault_usd=args.seed_vault,
        target_apy=args.target_apy,
    )

    if args.status:
        print_status(cfg.state_path)
        return
    core = SovereignCore(cfg)
    print(f"Booting sovereign core -> {cfg.state_path}")
    state = core.run(ticks=args.ticks, interval=args.interval, verbose=not args.quiet)
    print(
        f"\nDone at tick {state.tick}: net worth ${state.net_worth_usd:,.0f} "
        f"({state.progress:.1%} of ${state.vault_target_usd:,.0f}), "
        f"blended APY {state.blended_apy:.1%}, "
        f"{len(state.workers)} leases, {len(state.agents)} agents."
    )


if __name__ == "__main__":
    main()

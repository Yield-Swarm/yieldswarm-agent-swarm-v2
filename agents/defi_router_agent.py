#!/usr/bin/env python3
"""YieldSwarm DeFiRouter agent — bridge/swap route optimization with circuit breaker.

Usage:
  python3 agents/defi_router_agent.py              # simulate default $32.50 portfolio
  python3 agents/defi_router_agent.py --json        # JSON output
  DEFI_ROUTER_DRY_RUN=0 python3 agents/defi_router_agent.py  # execution path (multi-sig gated)

Env:
  DEFI_ROUTER_DRY_RUN=1           default dry-run
  DEFI_ROUTER_FEE_THRESHOLD_PCT=30 circuit breaker threshold
  NOTION_API_KEY                  Vault: yieldswarm/data/integrations/notion
  NOTION_TREASURY_DATABASE_ID     Notion treasury database
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from services.cross_chain.defi_router.agent import DeFiRouterAgent  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="YieldSwarm DeFiRouter agent")
    parser.add_argument("--json", action="store_true", help="Emit JSON only")
    parser.add_argument(
        "--portfolio-usd",
        type=float,
        default=None,
        help="Override total portfolio USD (scales default ETH/Curve/AVAX mix)",
    )
    args = parser.parse_args()

    agent = DeFiRouterAgent()
    if args.portfolio_usd:
        from services.cross_chain.defi_router.models import AssetPosition, Chain, Portfolio

        ratio = args.portfolio_usd / 32.50
        pf = Portfolio(
            positions=[
                AssetPosition("ETH", round(16.0 * ratio, 2), Chain.ETHEREUM),
                AssetPosition("CURVE_LP", round(14.0 * ratio, 2), Chain.CURVE),
                AssetPosition("AVAX", round(2.50 * ratio, 2), Chain.AVALANCHE),
            ]
        )
        result = agent.run(pf)
    else:
        result = agent.run()

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        report_path = agent.state_dir / "execution_report.txt"
        if report_path.exists():
            print(report_path.read_text())
        else:
            print(json.dumps(result, indent=2))

    return 1 if result.get("status") == "HALTED" else 0


if __name__ == "__main__":
    raise SystemExit(main())

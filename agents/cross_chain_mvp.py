#!/usr/bin/env python3
"""Cross-chain MVP agent — Jupiter quote + Uniswap V4 auction simulation."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from services.cross_chain.great_delta_route import route_revenue_through_treasury  # noqa: E402
from services.cross_chain.jupiter import JupiterClient, SOL_MINT, USDC_MINT  # noqa: E402
from services.cross_chain.uniswap_v4 import UniswapV4HookClient  # noqa: E402


def run_strategy(*, dry_run: bool = True) -> dict:
    jupiter = JupiterClient()
    uniswap = UniswapV4HookClient()

    sol_amount = int(os.getenv("CROSS_CHAIN_JUPITER_AMOUNT", "1000000"))
    jupiter_quote = jupiter.quote(input_mint=SOL_MINT, output_mint=USDC_MINT, amount=sol_amount)

    auction = uniswap.simulate_auction(
        pool_id=os.getenv("UNISWAP_V4_POOL_ID", "0x" + "aa" * 32),
        bid_amount_wei=int(os.getenv("UNISWAP_V4_BID_WEI", "1000000000000000")),
        bidder=os.getenv("UNISWAP_V4_BIDDER", "0x0000000000000000000000000000000000000001"),
    )

    est_jupiter_fee = 0.0
    if jupiter_quote.get("ok"):
        out = jupiter_quote.get("out_amount", 0)
        est_jupiter_fee = max(0.001, out / 1_000_000 * 0.001)

    est_uniswap_fee = 0.05 if auction.get("won_auction") else 0.0
    treasury_routes = [
        route_revenue_through_treasury(est_jupiter_fee, source="jupiter", execution_id="jupiter-mvp"),
        route_revenue_through_treasury(est_uniswap_fee, source="uniswap_v4", execution_id="univ4-mvp"),
    ]

    swap_result = None
    if jupiter_quote.get("ok") and not dry_run:
        swap_result = jupiter.build_swap(
            quote=jupiter_quote,
            user_public_key=os.getenv("SOLANA_HOT_WALLET_PUBKEY", ""),
            dry_run=False,
        )

    return {
        "status": "simulated" if dry_run else "executed",
        "dry_run": dry_run,
        "jupiter_quote": jupiter_quote,
        "uniswap_auction": auction,
        "treasury_routes": treasury_routes,
        "swap_result": swap_result,
    }


def main() -> None:
    dry_run = os.getenv("CROSS_CHAIN_DRY_RUN", "true").lower() in {"1", "true", "yes"}
    report = run_strategy(dry_run=dry_run)
    out_path = Path(os.getenv("CROSS_CHAIN_REPORT_PATH", REPO_ROOT / ".run" / "cross-chain-mvp.json"))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], "output": str(out_path)}, indent=2))


if __name__ == "__main__":
    main()

"""Cross-chain execution loop for sovereign Iteration 100 controller."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from services.cross_chain.great_delta_route import route_revenue_through_treasury
from services.cross_chain.jupiter import JupiterClient, SOL_MINT, USDC_MINT, jupiter_health
from services.cross_chain.uniswap_v4 import UniswapV4HookClient, uniswap_v4_health


class CrossChainExecutionLoop:
    """Runs Jupiter + Uniswap V4 MVP strategies each sovereign cycle."""

    def __init__(self) -> None:
        self.jupiter = JupiterClient()
        self.uniswap = UniswapV4HookClient()
        self.report_path = Path(
            os.getenv("CROSS_CHAIN_REPORT_PATH", ".run/cross-chain-mvp.json")
        )

    def run(self, cycle: int) -> tuple[list[dict[str, Any]], dict[str, Any]]:
        actions: list[dict[str, Any]] = []
        j_health = jupiter_health()
        u_health = uniswap_v4_health()

        quote = self.jupiter.quote(input_mint=SOL_MINT, output_mint=USDC_MINT, amount=1_000_000)
        if quote.get("ok"):
            est_fee = max(0.001, quote.get("out_amount", 0) / 1_000_000 * 0.001)
            treasury = route_revenue_through_treasury(
                est_fee, source="jupiter", execution_id=f"cycle-{cycle}"
            )
            actions.append(
                {
                    "provider": "jupiter",
                    "action": "quote",
                    "out_amount": quote.get("out_amount"),
                    "treasury_route": treasury,
                }
            )

        auction = self.uniswap.simulate_auction(
            pool_id=os.getenv("UNISWAP_V4_POOL_ID", "0x" + "aa" * 32),
            bid_amount_wei=int(os.getenv("UNISWAP_V4_BID_WEI", "1000000000000000")),
            bidder=os.getenv("UNISWAP_V4_BIDDER", "0x0000000000000000000000000000000000000001"),
        )
        if auction.get("ok"):
            fee = 0.05 if auction.get("won_auction") else 0.0
            treasury = route_revenue_through_treasury(
                fee, source="uniswap_v4", execution_id=f"cycle-{cycle}"
            )
            actions.append(
                {
                    "provider": "uniswap_v4",
                    "action": "auction_sim",
                    "won_auction": auction.get("won_auction"),
                    "treasury_route": treasury,
                }
            )

        metrics = {
            "jupiter_live": j_health.get("live", False),
            "uniswap_live": u_health.get("live", False),
            "executions": len(actions),
            "estimated_revenue_usd": round(
                sum(a["treasury_route"]["gross_revenue_usd"] for a in actions), 6
            ),
        }

        self.report_path.parent.mkdir(parents=True, exist_ok=True)
        self.report_path.write_text(
            json.dumps({"cycle": cycle, "actions": actions, "metrics": metrics}, indent=2),
            encoding="utf-8",
        )
        return actions, metrics

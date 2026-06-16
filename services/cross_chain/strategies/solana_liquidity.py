"""Solana liquidity — Jupiter aggregation + Orca/Raydium LP."""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from typing import Any, Dict, Optional

from services.cross_chain.great_delta import route_revenue_to_treasury
from services.cross_chain.strategies.base import BaseStrategy
from services.cross_chain.types import ExecutionReceipt, ExecutionStatus, StrategyJob


class SolanaLiquidityStrategy(BaseStrategy):
    venue = "jupiter"
    chain = "solana"

    def execute(self, job: StrategyJob) -> ExecutionReceipt:
        params = job.params
        action = params.get("action", "swap")  # swap | lp_orca | lp_raydium | farm
        input_mint = params.get("input_mint", "So11111111111111111111111111111111111111112")
        output_mint = params.get("output_mint", "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v")
        amount = float(params.get("amount", 0.0))
        slippage_bps = int(params.get("slippage_bps", 50))

        metrics: Dict[str, Any] = {
            "action": action,
            "input_mint": input_mint,
            "output_mint": output_mint,
            "amount": amount,
            "slippage_bps": slippage_bps,
        }

        quote = self._jupiter_quote(input_mint, output_mint, amount, slippage_bps)
        if quote:
            metrics["jupiter_quote"] = quote
            out_usd = float(quote.get("out_amount_usd", 0.0))
        else:
            out_usd = amount * float(params.get("sol_price_usd", 150.0)) * 0.001

        if action.startswith("lp_"):
            venue = "orca" if "orca" in action else "raydium"
            metrics["lp_venue"] = venue
            self.venue = venue

        estimated_yield = out_usd * float(params.get("expected_yield_bps", 15)) / 10_000
        split = route_revenue_to_treasury(
            estimated_yield, source="solana", strategy=action
        )

        if job.dry_run:
            return self._receipt(
                job,
                status=ExecutionStatus.DRY_RUN,
                gross_revenue_usd=estimated_yield,
                treasury_split=split,
                metrics={**metrics, "simulated_at": int(time.time())},
            )

        api = os.getenv("YIELDSWARM_CROSS_CHAIN_API_URL", "").rstrip("/")
        if not api:
            return self._receipt(
                job,
                status=ExecutionStatus.SKIPPED,
                error="Set YIELDSWARM_CROSS_CHAIN_API_URL for live Solana execution",
                metrics=metrics,
                treasury_split=split,
            )

        return self._receipt(
            job,
            status=ExecutionStatus.QUOTED,
            gross_revenue_usd=estimated_yield,
            treasury_split=split,
            metrics={**metrics, "api": api},
        )

    def _jupiter_quote(
        self,
        input_mint: str,
        output_mint: str,
        amount: float,
        slippage_bps: int,
    ) -> Optional[Dict[str, Any]]:
        """Fetch Jupiter v6 quote when API key + amount available."""
        if amount <= 0:
            return None

        base = os.getenv("JUPITER_API_BASE", "https://quote-api.jup.ag/v6")
        api_key = os.getenv("JUPITER_API_KEY", "")
        lamports = int(amount * 1_000_000_000)  # assume SOL-like decimals for scaffold

        url = (
            f"{base}/quote?inputMint={input_mint}&outputMint={output_mint}"
            f"&amount={lamports}&slippageBps={slippage_bps}"
        )
        headers = {"Accept": "application/json"}
        if api_key and not api_key.startswith("your_"):
            headers["x-api-key"] = api_key

        try:
            req = urllib.request.Request(url, headers=headers, method="GET")
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode())
            out_amount = int(data.get("outAmount", 0))
            return {
                "in_amount": lamports,
                "out_amount": out_amount,
                "out_amount_usd": out_amount / 1_000_000,  # USDC approx
                "price_impact_pct": data.get("priceImpactPct"),
                "route_plan_len": len(data.get("routePlan", [])),
            }
        except (urllib.error.URLError, json.JSONDecodeError, TimeoutError):
            return None

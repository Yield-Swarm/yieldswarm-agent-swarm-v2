"""Uniswap V4 hook + Dutch auction strategy (scaffold → production)."""

from __future__ import annotations

import os
import time
from typing import Any, Dict

from services.cross_chain.great_delta import route_revenue_to_treasury
from services.cross_chain.strategies.base import BaseStrategy
from services.cross_chain.types import ExecutionReceipt, ExecutionStatus, StrategyJob


class UniswapV4HookStrategy(BaseStrategy):
    """Agent-managed V4 hook positions with Dutch auction order flow."""

    venue = "uniswap_v4"
    chain = "ethereum"

    def execute(self, job: StrategyJob) -> ExecutionReceipt:
        params = job.params
        auction_type = params.get("auction_type", "dutch")
        pool_id = params.get("pool_id", "")
        notional_usd = float(params.get("notional_usd", 0.0))
        hook_address = params.get("hook_address") or os.getenv("UNISWAP_V4_HOOK_ADDRESS", "")

        metrics: Dict[str, Any] = {
            "auction_type": auction_type,
            "pool_id": pool_id,
            "hook_address": hook_address or "(unset)",
            "mev_protection": params.get("mev_protection", True),
            "start_price_bps": params.get("start_price_bps", 10_000),
            "end_price_bps": params.get("end_price_bps", 9_500),
            "duration_seconds": params.get("duration_seconds", 300),
        }

        if job.dry_run or not hook_address:
            estimated = notional_usd * float(params.get("expected_yield_bps", 25)) / 10_000
            split = route_revenue_to_treasury(
                estimated, source="uniswap_v4", strategy=auction_type
            )
            return self._receipt(
                job,
                status=ExecutionStatus.DRY_RUN,
                gross_revenue_usd=estimated,
                treasury_split=split,
                metrics={**metrics, "simulated_at": int(time.time())},
            )

        # Live path: delegate to unified wallet / hook executor API
        api = os.getenv("YIELDSWARM_CROSS_CHAIN_API_URL", "").rstrip("/")
        if not api:
            return self._receipt(
                job,
                status=ExecutionStatus.SKIPPED,
                error="Set YIELDSWARM_CROSS_CHAIN_API_URL for live Uniswap V4 execution",
                metrics=metrics,
            )

        return self._receipt(
            job,
            status=ExecutionStatus.QUOTED,
            metrics={**metrics, "api": api, "note": "wire POST /cross-chain/uniswap/v4/execute"},
        )

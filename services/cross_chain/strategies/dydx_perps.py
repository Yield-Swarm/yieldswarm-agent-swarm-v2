"""dYdX v4 perpetual futures — hedge + directional yield."""

from __future__ import annotations

import os
import time
from typing import Any, Dict

from services.cross_chain.great_delta import route_revenue_to_treasury
from services.cross_chain.strategies.base import BaseStrategy
from services.cross_chain.types import ExecutionReceipt, ExecutionStatus, StrategyJob


class DydxPerpsStrategy(BaseStrategy):
    venue = "dydx"
    chain = "dydx"

    def execute(self, job: StrategyJob) -> ExecutionReceipt:
        params = job.params
        action = params.get("action", "open")  # open | close | hedge
        market = params.get("market", "BTC-USD")
        side = params.get("side", "long")
        size_usd = float(params.get("size_usd", 0.0))
        leverage = float(params.get("leverage", 1.0))

        metrics: Dict[str, Any] = {
            "action": action,
            "market": market,
            "side": side,
            "size_usd": size_usd,
            "leverage": leverage,
            "hedge_mode": params.get("hedge_mode", False),
        }

        # PnL estimate for simulation (sovereign loop ingestion)
        pnl_bps = float(params.get("expected_pnl_bps", 0.0))
        gross = size_usd * pnl_bps / 10_000 if action != "close" else size_usd * pnl_bps / 10_000
        split = route_revenue_to_treasury(gross, source="dydx", strategy=f"{action}_{market}")

        if job.dry_run:
            return self._receipt(
                job,
                status=ExecutionStatus.DRY_RUN,
                gross_revenue_usd=gross,
                treasury_split=split,
                metrics={**metrics, "simulated_at": int(time.time())},
            )

        api_key = os.getenv("DYDX_API_KEY", "")
        api = os.getenv("DYDX_API_BASE", "https://indexer.dydx.trade/v4")
        if not api_key or api_key.startswith("your_"):
            return self._receipt(
                job,
                status=ExecutionStatus.SKIPPED,
                error="Set DYDX_API_KEY in Vault kv/yieldswarm/integrations/dydx",
                metrics={**metrics, "api": api},
                treasury_split=split,
            )

        return self._receipt(
            job,
            status=ExecutionStatus.QUOTED,
            gross_revenue_usd=gross,
            treasury_split=split,
            metrics={**metrics, "api": api, "note": "wire indexer + client for live orders"},
        )

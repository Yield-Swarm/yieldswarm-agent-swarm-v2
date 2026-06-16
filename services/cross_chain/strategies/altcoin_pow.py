"""Altcoin PoW mining expansion beyond Bittensor."""

from __future__ import annotations

import os
import time
from typing import Any, Dict, List

from services.cross_chain.great_delta import route_revenue_to_treasury
from services.cross_chain.strategies.base import BaseStrategy
from services.cross_chain.types import ExecutionReceipt, ExecutionStatus, StrategyJob

# High-ROI / DePIN-adjacent candidates — operator configures enabled set
MINING_REGISTRY: Dict[str, Dict[str, Any]] = {
    "bittensor": {
        "chain": "bittensor",
        "hardware": "RTX_3090",
        "revenue_model": "tao_emissions",
        "status": "live",
        "sdl": "deploy/akash-bittensor-miner.sdl.yml",
    },
    "grass": {
        "chain": "solana_depin",
        "hardware": "cpu",
        "revenue_model": "grass_points",
        "status": "planned",
    },
    "flux": {
        "chain": "flux",
        "hardware": "gpu",
        "revenue_model": "block_rewards",
        "status": "candidate",
    },
    "kaspa": {
        "chain": "kaspa",
        "hardware": "gpu",
        "revenue_model": "block_rewards",
        "status": "candidate",
    },
    "ironfish": {
        "chain": "ironfish",
        "hardware": "gpu",
        "revenue_model": "block_rewards",
        "status": "candidate",
    },
    "prn_depin": {
        "chain": "depin",
        "hardware": "cpu_gpu",
        "revenue_model": "network_rewards",
        "status": "research",
    },
}


class AltcoinPowStrategy(BaseStrategy):
    venue = "pow_mining"
    chain = "multi"

    def execute(self, job: StrategyJob) -> ExecutionReceipt:
        params = job.params
        coin = params.get("coin", "bittensor")
        action = params.get("action", "status")  # status | route_rewards | scale

        spec = MINING_REGISTRY.get(coin)
        if not spec:
            return self._receipt(
                job,
                status=ExecutionStatus.FAILED,
                error=f"unknown coin: {coin}",
                metrics={"available": list(MINING_REGISTRY.keys())},
            )

        daily_usd = float(params.get("estimated_daily_usd", 0.0))
        if daily_usd <= 0 and coin == "bittensor":
            daily_usd = float(os.getenv("BITTENSOR_EST_DAILY_USD", "0"))

        split = route_revenue_to_treasury(daily_usd, source="pow", strategy=coin)
        metrics: Dict[str, Any] = {
            "coin": coin,
            "action": action,
            "spec": spec,
            "enabled_coins": self._enabled_coins(),
        }

        if job.dry_run or action == "status":
            return self._receipt(
                job,
                status=ExecutionStatus.DRY_RUN,
                gross_revenue_usd=daily_usd,
                treasury_split=split,
                metrics={**metrics, "simulated_at": int(time.time())},
            )

        return self._receipt(
            job,
            status=ExecutionStatus.QUOTED,
            gross_revenue_usd=daily_usd,
            treasury_split=split,
            metrics=metrics,
        )

    def _enabled_coins(self) -> List[str]:
        raw = os.getenv("POW_MINING_COINS", "bittensor,grass")
        return [c.strip() for c in raw.split(",") if c.strip()]

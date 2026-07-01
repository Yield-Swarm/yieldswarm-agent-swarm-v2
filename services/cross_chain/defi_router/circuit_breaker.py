"""Circuit breaker — halts execution when fees exceed retention threshold."""

from __future__ import annotations

import os

from services.cross_chain.defi_router.models import CircuitBreakerResult, RoutePlan


class CircuitBreaker:
    """Layer 4 security: auto-halt when fee drag exceeds threshold."""

    def __init__(self, threshold_pct: float | None = None):
        env = os.getenv("DEFI_ROUTER_FEE_THRESHOLD_PCT")
        self.threshold_pct = threshold_pct if threshold_pct is not None else float(env or 30.0)

    def evaluate(self, route: RoutePlan, portfolio_usd: float) -> CircuitBreakerResult:
        fee_pct = route.fee_pct
        triggered = fee_pct > self.threshold_pct

        if triggered:
            min_viable = self._estimate_min_viable_portfolio(route.strategy_id)
            reason = (
                f"Projected fees {fee_pct:.1f}% exceed {self.threshold_pct:.0f}% threshold "
                f"on ${portfolio_usd:.2f} portfolio"
            )
            recommendation = (
                f"WAIT — accumulate to ${min_viable:.0f}+ before executing "
                f"({route.strategy_name})"
            )
        else:
            reason = f"Fees {fee_pct:.1f}% within {self.threshold_pct:.0f}% threshold"
            recommendation = "PROCEED — route viable; confirm multi-sig approval"

        return CircuitBreakerResult(
            triggered=triggered,
            threshold_pct=self.threshold_pct,
            actual_fee_pct=fee_pct,
            reason=reason,
            recommendation=recommendation,
        )

    def _estimate_min_viable_portfolio(self, strategy_id: str) -> float:
        """Portfolio size where retention crosses 70% (fee drag < 30%)."""
        # Arbitrum hub has ~$8 fixed mainnet gas; solve: 8 + 0.04*P = 0.30*P → P ≈ 33
        # Real slippage pushes viable zone to ~$50
        floors = {
            "arbitrum_hub": 50.0,
            "direct_mainnet": 80.0,
            "symbiosis_fast": 55.0,
        }
        return floors.get(strategy_id, 50.0)

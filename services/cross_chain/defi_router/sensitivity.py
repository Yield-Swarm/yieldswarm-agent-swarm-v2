"""Portfolio sensitivity analysis — when routes become viable."""

from __future__ import annotations

from typing import Dict, List

from services.cross_chain.defi_router.models import AssetPosition, Chain, Portfolio
from services.cross_chain.defi_router.router import RouteOptimizer

VIABILITY_RETENTION_PCT = 70.0


def sensitivity_analysis(
    sizes_usd: List[float] | None = None,
    *,
    threshold_pct: float = 30.0,
) -> List[Dict[str, object]]:
    """Return retention % at each portfolio size for the best route."""
    sizes = sizes_usd or [10, 20, 32.5, 50, 75, 100, 250, 500, 1000]
    optimizer = RouteOptimizer()
    rows: List[Dict[str, object]] = []

    for size in sizes:
        portfolio = _scaled_portfolio(size)
        best = optimizer.best_route(portfolio)
        viable = best.retention_pct >= VIABILITY_RETENTION_PCT and best.fee_pct <= threshold_pct
        rows.append(
            {
                "portfolioUsd": size,
                "strategy": best.strategy_name,
                "feePct": round(best.fee_pct, 1),
                "retentionPct": round(best.retention_pct, 1),
                "totalFeesUsd": round(best.total_fees_usd, 2),
                "netOutputUsd": round(best.net_output_usd, 2),
                "viable": viable,
            }
        )
    return rows


def min_viable_portfolio(threshold_pct: float = 30.0) -> float:
    """Binary search portfolio size where retention crosses 70%."""
    lo, hi = 10.0, 5000.0
    optimizer = RouteOptimizer()
    for _ in range(32):
        mid = (lo + hi) / 2
        best = optimizer.best_route(_scaled_portfolio(mid))
        if best.fee_pct <= threshold_pct:
            hi = mid
        else:
            lo = mid
    return round(hi, 0)


def _scaled_portfolio(total_usd: float) -> Portfolio:
    base = Portfolio.yieldswarm_default()
    ratio = total_usd / base.total_usd
    return Portfolio(
        positions=[
            AssetPosition(p.symbol, round(p.amount_usd * ratio, 2), p.chain) for p in base.positions
        ]
    )

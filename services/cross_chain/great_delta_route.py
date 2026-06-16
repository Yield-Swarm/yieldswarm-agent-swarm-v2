"""Route cross-chain execution revenue through Great Delta 50/30/15/5."""

from __future__ import annotations

from typing import Any


def route_revenue_through_treasury(
    gross_revenue_usd: float,
    *,
    source: str,
    execution_id: str | None = None,
) -> dict[str, Any]:
    """Split gross revenue into canonical treasury buckets."""
    amount = max(0.0, float(gross_revenue_usd))
    to_core = round(amount * 0.50, 6)
    to_growth = round(amount * 0.30, 6)
    to_insurance = round(amount * 0.15, 6)
    to_ops = round(amount - to_core - to_growth - to_insurance, 6)
    return {
        "source": source,
        "execution_id": execution_id,
        "gross_revenue_usd": round(amount, 6),
        "split_bps": {"core": 5000, "growth": 3000, "insurance": 1500, "ops": 500},
        "buckets": {
            "coreTreasury": to_core,
            "growthTreasury": to_growth,
            "insuranceTreasury": to_insurance,
            "opsTreasury": to_ops,
        },
    }

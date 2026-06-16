"""Akash GPU ROI calculator — break-even tokens/sec at a given hourly cost."""

from __future__ import annotations


def calculate_akash_roi(
    hourly_cost: float,
    tokens_per_second: float,
    price_per_million_tokens: float,
    utilization_rate: float = 0.85,
    hours_per_day: int = 24,
) -> dict:
    """Return daily/monthly profit and break-even throughput."""
    daily_cost = hourly_cost * hours_per_day
    effective_tps = tokens_per_second * utilization_rate
    tokens_per_day = effective_tps * 3600 * hours_per_day
    daily_revenue = (tokens_per_day * price_per_million_tokens) / 1_000_000
    daily_profit = daily_revenue - daily_cost
    monthly_profit = daily_profit * 30
    break_even_tps = (hourly_cost * 1_000_000) / (3600 * price_per_million_tokens)

    return {
        "daily_cost": round(daily_cost, 2),
        "daily_revenue": round(daily_revenue, 2),
        "daily_profit": round(daily_profit, 2),
        "monthly_profit": round(monthly_profit, 2),
        "break_even_tokens_per_second": round(break_even_tps, 2),
        "utilization_rate": utilization_rate,
        "tokens_per_second": tokens_per_second,
        "hourly_cost": hourly_cost,
    }


def rtx5090_default() -> dict:
    """Example for live RTX 5090 @ ~$0.72/hr."""
    return calculate_akash_roi(
        hourly_cost=0.72,
        tokens_per_second=85,
        price_per_million_tokens=0.25,
        utilization_rate=0.80,
    )

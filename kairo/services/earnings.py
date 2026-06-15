"""Kairo earnings breakdown — app revenue + DePIN/crypto rewards."""

from __future__ import annotations

import os
from typing import Any


def _env_float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        return float(raw)
    except ValueError:
        return default


CUSTOMER_FEE_RATE = _env_float("KAIRO_CUSTOMER_FEE_RATE", 0.01)
DRIVER_PAY_MULTIPLIER = _env_float("KAIRO_DRIVER_PAY_MULTIPLIER", 2.0)
DEPIN_REWARD_PER_WEIGHT = _env_float("KAIRO_DEPIN_REWARD_PER_WEIGHT", 0.0025)


def estimate_rewards(driver_stats: dict[str, Any], trip_fare_usd: float = 0.0) -> dict[str, Any]:
    """Compute earnings breakdown for a driver."""
    reward_weight = float(driver_stats.get("reward_weight", 0.0))
    depin_rewards = round(reward_weight * DEPIN_REWARD_PER_WEIGHT, 4)
    app_earnings = round(trip_fare_usd * DRIVER_PAY_MULTIPLIER, 4)
    customer_fee = round(trip_fare_usd * CUSTOMER_FEE_RATE, 4) if trip_fare_usd else 0.0

    return {
        "driver_id": driver_stats.get("driver_id"),
        "evm_address": driver_stats.get("evm_address"),
        "packets": int(driver_stats.get("packets", 0)),
        "distance_km": round(float(driver_stats.get("distance_km", 0.0)), 3),
        "drive_seconds": int(driver_stats.get("drive_seconds", 0)),
        "mandelbrot_nodes": int(driver_stats.get("mandelbrot_nodes", 0)),
        "app_earnings_usd": app_earnings,
        "depin_rewards_usd": depin_rewards,
        "estimated_total_usd": round(app_earnings + depin_rewards, 4),
        "customer_fee_usd": customer_fee,
        "instant_cashout_available": app_earnings > 0,
        "last_contribution_at": driver_stats.get("last_contribution_at"),
        "fee_rates": {
            "customer_flat_fee": CUSTOMER_FEE_RATE,
            "driver_pay_multiplier": DRIVER_PAY_MULTIPLIER,
        },
    }

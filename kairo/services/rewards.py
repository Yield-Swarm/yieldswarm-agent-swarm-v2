"""Contribution and reward calculations for Kairo drivers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, List

from kairo.services.pipeline import MandelbrotNode


VAULT_TARGET_USD = 5_000_000.0
CUSTOMER_FEE_PCT = 0.01
DRIVER_PAY_MULTIPLIER = 2.0
DEPIN_SHARE_PCT = 0.15


@dataclass
class RideEconomics:
    fare_usd: float
    customer_fee_usd: float
    driver_pay_usd: float
    depin_earnings_usd: float
    platform_revenue_usd: float
    mandelbrot_bonus_usd: float

    def to_dict(self) -> dict[str, float]:
        return {
            "fare_usd": round(self.fare_usd, 2),
            "customer_fee_usd": round(self.customer_fee_usd, 2),
            "driver_pay_usd": round(self.driver_pay_usd, 2),
            "depin_earnings_usd": round(self.depin_earnings_usd, 2),
            "platform_revenue_usd": round(self.platform_revenue_usd, 2),
            "mandelbrot_bonus_usd": round(self.mandelbrot_bonus_usd, 2),
        }


def calculate_ride_economics(
    fare_usd: float,
    node: MandelbrotNode,
) -> RideEconomics:
    """1% customer fee, 2× driver pay, DePIN earnings breakdown."""
    customer_fee = fare_usd * CUSTOMER_FEE_PCT
    base_driver = fare_usd * 0.5
    driver_pay = base_driver * DRIVER_PAY_MULTIPLIER
    depin = fare_usd * DEPIN_SHARE_PCT
    mandelbrot_bonus = fare_usd * 0.01 * node.reward_weight
    platform = customer_fee + fare_usd * 0.1 - depin

    return RideEconomics(
        fare_usd=fare_usd,
        customer_fee_usd=customer_fee,
        driver_pay_usd=driver_pay + mandelbrot_bonus,
        depin_earnings_usd=depin,
        platform_revenue_usd=max(platform, 0),
        mandelbrot_bonus_usd=mandelbrot_bonus,
    )


def driver_contribution_summary(
    rides: List[dict[str, Any]],
    current_vault_usd: float,
) -> dict[str, Any]:
    """Dashboard payload for driver contribution toward $5M vault."""
    total_fares = sum(r.get("fare_usd", 0) for r in rides)
    total_depin = sum(r.get("depin_earnings_usd", 0) for r in rides)
    total_bonus = sum(r.get("mandelbrot_bonus_usd", 0) for r in rides)
    progress_pct = min(100.0, (current_vault_usd / VAULT_TARGET_USD) * 100)

    daily_rate = total_fares * 0.02 if total_fares else 0
    days_to_target = (
        (VAULT_TARGET_USD - current_vault_usd) / daily_rate if daily_rate > 0 else None
    )

    return {
        "vault_target_usd": VAULT_TARGET_USD,
        "current_vault_usd": round(current_vault_usd, 2),
        "progress_pct": round(progress_pct, 2),
        "ride_count": len(rides),
        "total_fares_usd": round(total_fares, 2),
        "total_depin_usd": round(total_depin, 2),
        "total_mandelbrot_bonus_usd": round(total_bonus, 2),
        "compounding_daily_rate_usd": round(daily_rate, 2),
        "projected_days_to_5m": round(days_to_target, 1) if days_to_target else None,
        "customer_fee_pct": CUSTOMER_FEE_PCT,
        "driver_pay_multiplier": DRIVER_PAY_MULTIPLIER,
    }

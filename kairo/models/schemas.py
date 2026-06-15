"""Kairo data models."""

from dataclasses import dataclass
from typing import Optional


@dataclass
class TripQuote:
    distance_km: float
    duration_min: float
    base_fare_usd: float
    customer_fee_pct: float = 0.01
    driver_multiplier: float = 2.0

    @property
    def customer_total_usd(self) -> float:
        subtotal = self.base_fare_usd
        fee = subtotal * self.customer_fee_pct
        return round(subtotal + fee, 2)

    @property
    def customer_fee_usd(self) -> float:
        return round(self.base_fare_usd * self.customer_fee_pct, 2)

    @property
    def driver_app_pay_usd(self) -> float:
        return round(self.base_fare_usd * self.driver_multiplier, 2)

    @property
    def depin_reward_estimate_usd(self) -> float:
        score = self.distance_km * 0.01 + self.duration_min * 0.005
        return round(score * 0.02, 4)


@dataclass
class DriverEarnings:
    driver_id: str
    app_revenue_usd: float
    depin_rewards_usd: float
    crypto_rewards_usd: float = 0.0
    instant_cashout_available: bool = True

    @property
    def total_usd(self) -> float:
        return round(self.app_revenue_usd + self.depin_rewards_usd + self.crypto_rewards_usd, 2)

"""Kairo payment fee engine — customer 1%, driver 2x pay, instant cashout."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional


CUSTOMER_FEE_RATE = Decimal("0.01")  # 1% flat on ride fare
DRIVER_MULTIPLIER = Decimal("2.0")   # 2x base pay
INSTANT_CASHOUT_FEE = Decimal("0.015")  # 1.5% instant cashout fee
DEPIN_REWARD_SHARE = Decimal("0.10")  # 10% of DePIN rewards to driver


@dataclass
class RideFare:
    base_fare_usd: Decimal
    distance_miles: Decimal
    duration_min: Decimal
    surge_multiplier: Decimal = Decimal("1.0")


@dataclass
class EarningsBreakdown:
    """Full earnings breakdown for a Kairo driver."""

    ride_id: str
    driver_id: str
    # App revenue
    base_pay_usd: Decimal
    driver_bonus_usd: Decimal  # from 2x multiplier
    customer_fee_usd: Decimal
    platform_revenue_usd: Decimal
    # DePIN / crypto
    depin_reward_usd: Decimal
    crypto_reward_usd: Decimal
    # Totals
    gross_earnings_usd: Decimal
    instant_cashout_available_usd: Decimal
    instant_cashout_fee_usd: Decimal
    net_after_cashout_usd: Decimal

    def to_dict(self) -> dict:
        return {k: str(v) for k, v in self.__dict__.items()}


def _usd(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def calculate_base_pay(fare: RideFare) -> Decimal:
    """Standard base driver pay before 2x multiplier."""
    per_mile = Decimal("1.25")
    per_min = Decimal("0.35")
    return _usd(
        (fare.base_fare_usd + fare.distance_miles * per_mile + fare.duration_min * per_min)
        * fare.surge_multiplier,
    )


def calculate_earnings(
    ride_id: str,
    driver_id: str,
    fare: RideFare,
    depin_reward_usd: Decimal = Decimal("0"),
    crypto_reward_usd: Decimal = Decimal("0"),
    instant_cashout: bool = False,
) -> EarningsBreakdown:
    """Compute full earnings breakdown for a completed ride."""
    base_pay = calculate_base_pay(fare)
    driver_bonus = _usd(base_pay * (DRIVER_MULTIPLIER - Decimal("1")))
    total_driver_pay = _usd(base_pay + driver_bonus)

    ride_total = _usd(base_pay * DRIVER_MULTIPLIER / (Decimal("1") - CUSTOMER_FEE_RATE))
    customer_fee = _usd(ride_total * CUSTOMER_FEE_RATE)
    platform_revenue = _usd(customer_fee)

    depin_share = _usd(depin_reward_usd * DEPIN_REWARD_SHARE)
    crypto_share = crypto_reward_usd

    gross = _usd(total_driver_pay + depin_share + crypto_share)
    cashout_fee = _usd(gross * INSTANT_CASHOUT_FEE) if instant_cashout else Decimal("0")
    net = _usd(gross - cashout_fee)

    return EarningsBreakdown(
        ride_id=ride_id,
        driver_id=driver_id,
        base_pay_usd=base_pay,
        driver_bonus_usd=driver_bonus,
        customer_fee_usd=customer_fee,
        platform_revenue_usd=platform_revenue,
        depin_reward_usd=depin_share,
        crypto_reward_usd=crypto_share,
        gross_earnings_usd=gross,
        instant_cashout_available_usd=gross if instant_cashout else Decimal("0"),
        instant_cashout_fee_usd=cashout_fee,
        net_after_cashout_usd=net,
    )

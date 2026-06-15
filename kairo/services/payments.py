"""Kairo payment integration — wires existing Square/Wise/Web3 rails to driver earnings."""

from __future__ import annotations

from typing import Any

from kairo.services.earnings import estimate_rewards


def driver_payment_summary(
    driver_stats: dict[str, Any],
    *,
    trip_fare_usd: float,
    instant_cashout: bool = False,
) -> dict[str, Any]:
    """Merge app payment rails breakdown with DePIN contribution rewards."""
    breakdown = estimate_rewards(driver_stats, trip_fare_usd=trip_fare_usd)
    breakdown["instant_cashout_requested"] = instant_cashout
    breakdown["payment_rails"] = {
        "square": "card + ACH deposits via src/lib/payments/square.ts",
        "wise": "bank transfer + instant cashout via src/lib/payments/wise.ts",
        "web3": "on-chain wallet via frontend/src/wallet and src/lib/web3/*",
    }
    breakdown["fee_model"] = {
        "customer_flat_fee_rate": breakdown["fee_rates"]["customer_flat_fee"],
        "driver_pay_multiplier": breakdown["fee_rates"]["driver_pay_multiplier"],
        "instant_cashout": instant_cashout,
    }
    return breakdown

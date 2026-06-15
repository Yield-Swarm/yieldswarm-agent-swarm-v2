"""Kairo payment service — wires Square/Wise/Web3 rails to driver earnings."""

from __future__ import annotations

import json
import os
import urllib.request
from decimal import Decimal
from typing import Any, Optional

from kairo.payments.fees import EarningsBreakdown, RideFare, calculate_earnings


class KairoPaymentService:
    """Bridge between Kairo driver earnings and YieldSwarm payment rails."""

    def __init__(self, payments_api_base: Optional[str] = None) -> None:
        self.api_base = payments_api_base or os.environ.get(
            "PAYMENTS_API_URL",
            "http://localhost:3000/api",
        )

    def process_ride_completion(
        self,
        ride_id: str,
        driver_id: str,
        driver_evm_address: str,
        fare: RideFare,
        depin_reward_usd: Decimal = Decimal("0"),
        crypto_reward_usd: Decimal = Decimal("0"),
        instant_cashout: bool = False,
    ) -> EarningsBreakdown:
        breakdown = calculate_earnings(
            ride_id=ride_id,
            driver_id=driver_id,
            fare=fare,
            depin_reward_usd=depin_reward_usd,
            crypto_reward_usd=crypto_reward_usd,
            instant_cashout=instant_cashout,
        )

        if instant_cashout and breakdown.net_after_cashout_usd > 0:
            self._request_wise_payout(
                driver_id=driver_id,
                amount_usd=str(breakdown.net_after_cashout_usd),
                reference=f"kairo-cashout-{ride_id}",
            )
        elif breakdown.gross_earnings_usd > 0:
            self._credit_driver_balance(
                driver_id=driver_id,
                driver_evm_address=driver_evm_address,
                amount_usd=str(breakdown.gross_earnings_usd),
                reference=f"kairo-ride-{ride_id}",
            )

        return breakdown

    def _credit_driver_balance(
        self,
        driver_id: str,
        driver_evm_address: str,
        amount_usd: str,
        reference: str,
    ) -> dict[str, Any]:
        body = json.dumps({
            "userId": driver_id,
            "amount": amount_usd,
            "currency": "USD",
            "reference": reference,
            "walletAddress": driver_evm_address,
            "source": "kairo-ride",
        }).encode()
        return self._post(f"{self.api_base}/deposits/wise", body)

    def _request_wise_payout(
        self,
        driver_id: str,
        amount_usd: str,
        reference: str,
    ) -> dict[str, Any]:
        body = json.dumps({
            "userId": driver_id,
            "amount": amount_usd,
            "currency": "USD",
            "reference": reference,
            "rail": "wise",
            "instant": True,
        }).encode()
        return self._post(f"{self.api_base}/withdrawals/bank", body)

    def _post(self, url: str, body: bytes) -> dict[str, Any]:
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                return json.loads(resp.read().decode())
        except Exception as exc:
            return {"error": str(exc), "url": url}

"""Cosmic onboarding API — KYC birth fields + house/deity assignment."""

from __future__ import annotations

import hashlib
import os
from datetime import date, time
from typing import Any

from swarms.cosmic_onboarding.engines.astrology_engine import AstrologyEngine, BirthMetrics
from swarms.cosmic_onboarding.engines.deity_router import DeityRouter
from swarms.cosmic_onboarding.engines.runic_yield import RunicYieldDistributor, YieldParticipant


class CosmicOnboardingService:
    def __init__(self) -> None:
        self.astrology = AstrologyEngine()
        self.deity_router = DeityRouter()
        self.yield_dist = RunicYieldDistributor()

    def onboard(self, payload: dict[str, Any]) -> dict[str, Any]:
        metrics = BirthMetrics(
            birth_date=date.fromisoformat(payload["birthDate"]),
            birth_time=time.fromisoformat(payload["birthTime"]),
            latitude=float(payload["birthLatitude"]),
            longitude=float(payload["birthLongitude"]),
        )
        email = payload["email"].strip().lower()
        user_key = hashlib.sha256(email.encode()).hexdigest()
        house = self.astrology.assign_house(metrics)
        deity = self.deity_router.assign(user_key, house["houseId"])
        return {
            "schemaVersion": "cosmic-onboarding/v1",
            "email": email,
            "kycVerified": bool(payload.get("kycVerified", False)),
            "house": house,
            "deity": deity,
            "runicLevel": 1,
            "runicXp": 0.0,
        }

    def distribute_pool(
        self,
        pool_usd: float,
        users: list[dict[str, Any]],
    ) -> dict[str, Any]:
        participants = [
            YieldParticipant(
                user_id=u["userId"],
                runic_level=int(u.get("runicLevel", 1)),
                runic_xp=float(u.get("runicXp", 0)),
                referred_infra_usd=float(u.get("referredInfraUsd", 0)),
                leased_hardware_hashrate=float(u.get("leasedHardwareHashrate", 0)),
            )
            for u in users
        ]
        return self.yield_dist.distribute(pool_usd, participants)

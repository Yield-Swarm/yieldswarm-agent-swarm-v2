"""DePIN reward estimation and 2x driver pay logic."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from kairo.config import settings
from kairo.db import db
from kairo.models.schemas import (
    DashboardSummary,
    DepinRewardEstimate,
    DriverPayQuote,
    PayoutRail,
)
from kairo.services.identity_service import IdentityService
from kairo.services.telemetry_pipeline import TelemetryPipeline


class RewardService:
    def __init__(self) -> None:
        self.identity = IdentityService()
        self.telemetry = TelemetryPipeline()

    def _contribution_points(self, stats: dict, driver: dict) -> float:
        distance = float(stats.get("total_distance_km") or 0)
        packets = int(stats.get("verified_packets") or 0)
        points = distance * 10 + packets * 0.5
        if driver.get("depin_helium_pubkey"):
            points *= 1.15  # HNT coverage boost
        if driver.get("depin_grass_node_id"):
            points *= 1.10  # GRASS bandwidth boost
        return points

    def depin_estimates(self, points: float, driver: dict) -> list[DepinRewardEstimate]:
        rewards = [
            DepinRewardEstimate(
                token="HNT",
                amount_usd=round(points * settings.hnt_rate_per_point, 4),
                contribution_points=round(points, 2),
                description="Helium network data coverage (Netzach node)",
            ),
            DepinRewardEstimate(
                token="GRASS",
                amount_usd=round(points * settings.grass_rate_per_point, 4),
                contribution_points=round(points, 2),
                description="Grass bandwidth sharing (Hod node)",
            ),
            DepinRewardEstimate(
                token="AKT",
                amount_usd=round(points * settings.akt_rate_per_point, 4),
                contribution_points=round(points, 2),
                description="Akash compute contribution (YieldSwarm shard)",
            ),
        ]
        if not driver.get("depin_helium_pubkey"):
            rewards[0].amount_usd *= 0.5
            rewards[0].description += " (no hotspot linked — reduced estimate)"
        if not driver.get("depin_grass_node_id"):
            rewards[1].amount_usd *= 0.5
            rewards[1].description += " (no Grass node linked — reduced estimate)"
        return rewards

    def pay_quote(self, driver_id: str) -> DriverPayQuote:
        driver = self.identity.get_driver(driver_id)
        if not driver:
            raise ValueError("Unknown driver")
        stats = self.telemetry.driver_stats(driver_id)
        distance = float(stats.get("total_distance_km") or 0)
        verified = int(stats.get("verified_packets") or 0)

        base = distance * settings.base_pay_rate_usd_per_km
        reasons: list[str] = []
        eligible = True

        if verified < settings.min_signed_packets_for_2x:
            eligible = False
            reasons.append(
                f"Need {settings.min_signed_packets_for_2x} signed packets (have {verified})"
            )
        if distance < settings.min_distance_km_for_2x:
            eligible = False
            reasons.append(
                f"Need {settings.min_distance_km_for_2x} km (have {distance:.2f})"
            )
        if not driver.get("depin_helium_pubkey") and not driver.get("depin_grass_node_id"):
            eligible = False
            reasons.append("Link Helium or Grass DePIN node for 2x multiplier")

        multiplier = settings.driver_pay_multiplier_verified if eligible else 1.0
        if eligible:
            reasons.append("2x verified telemetry + DePIN contribution active")

        destination = driver["evm_address"]
        rail = PayoutRail.EVM.value
        if settings.wise_business_email:
            rail = PayoutRail.WISE.value
            destination = settings.wise_business_email

        return DriverPayQuote(
            driver_id=driver_id,
            base_pay_usd=round(base, 4),
            multiplier=multiplier,
            total_pay_usd=round(base * multiplier, 4),
            eligible_for_2x=eligible,
            eligibility_reasons=reasons,
            rail=rail,
            destination=destination,
        )

    def dashboard(self, driver_id: str) -> DashboardSummary:
        driver = self.identity.get_driver(driver_id)
        if not driver:
            raise ValueError("Unknown driver")
        stats = self.telemetry.driver_stats(driver_id)
        points = self._contribution_points(stats, driver)
        pay = self.pay_quote(driver_id)
        last = stats.get("last_telemetry_at")

        nodes_raw = stats.get("tree_nodes") or []
        if nodes_raw and isinstance(nodes_raw[0], dict):
            tree_nodes = [n["tree_of_life_node"] for n in nodes_raw]
        else:
            tree_nodes = nodes_raw

        return DashboardSummary(
            driver_id=driver_id,
            kairo_user_id=driver["kairo_user_id"],
            evm_address=driver["evm_address"],
            iotex_address=driver["iotex_address"],
            total_distance_km=round(float(stats.get("total_distance_km") or 0), 4),
            signed_packets=int(stats.get("signed_packets") or 0),
            verified_packets=int(stats.get("verified_packets") or 0),
            active_shards=stats.get("active_shards", []),
            tree_nodes=tree_nodes,
            depin_rewards=self.depin_estimates(points, driver),
            pay_quote=pay,
            last_telemetry_at=datetime.fromisoformat(last) if last else None,
        )

    def settle_period(self, driver_id: str) -> dict:
        """Create contribution ledger + payout quote for settlement."""
        dash = self.dashboard(driver_id)
        ledger_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        db.insert(
            "contribution_ledger",
            {
                "id": ledger_id,
                "driver_id": driver_id,
                "period_start": now,
                "period_end": now,
                "total_distance_km": dash.total_distance_km,
                "signed_packets": dash.signed_packets,
                "mandelbrot_shards_json": str(dash.active_shards),
                "hnt_estimate_usd": dash.depin_rewards[0].amount_usd,
                "grass_estimate_usd": dash.depin_rewards[1].amount_usd,
                "akt_estimate_usd": dash.depin_rewards[2].amount_usd,
                "pay_multiplier": dash.pay_quote.multiplier,
                "base_pay_usd": dash.pay_quote.base_pay_usd,
                "total_pay_usd": dash.pay_quote.total_pay_usd,
                "payout_status": "quoted",
                "created_at": now,
            },
        )
        payout_id = str(uuid.uuid4())
        db.insert(
            "payout_events",
            {
                "id": payout_id,
                "driver_id": driver_id,
                "ledger_id": ledger_id,
                "amount_usd": dash.pay_quote.total_pay_usd,
                "multiplier": dash.pay_quote.multiplier,
                "rail": dash.pay_quote.rail,
                "destination": dash.pay_quote.destination,
                "status": "quoted",
                "created_at": now,
            },
        )
        return {
            "ledger_id": ledger_id,
            "payout_id": payout_id,
            "total_pay_usd": dash.pay_quote.total_pay_usd,
            "multiplier": dash.pay_quote.multiplier,
            "rail": dash.pay_quote.rail,
            "destination": dash.pay_quote.destination,
            "wise_note": (
                f"Route payout via Wise to {settings.wise_business_email}"
                if settings.wise_business_email
                else "Configure WISE_BUSINESS_EMAIL for Wise rail"
            ),
        }

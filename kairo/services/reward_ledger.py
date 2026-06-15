"""Basic reward tracking for Kairo driver telemetry contributions."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from kairo.models.driver import ContributionSummary
from kairo.services.earnings import estimate_rewards


class RewardLedger:
    """Append-only ledger of Mandelbrot-weighted reward events per driver."""

    def __init__(self, root: Path | None = None) -> None:
        self.root = root or Path(os.environ.get("KAIRO_STORE_DIR", ".data/kairo"))
        self.root.mkdir(parents=True, exist_ok=True)
        self._events_path = self.root / "reward_events.jsonl"
        self._balances_path = self.root / "reward_balances.json"

    def record(
        self,
        *,
        driver_id: str,
        evm_address: str,
        telemetry_id: str,
        reward_weight: float,
        shard_id: int,
        fare_usd: float = 0.0,
        signed_at: str,
    ) -> dict[str, Any]:
        earnings = estimate_rewards(
            {
                "driver_id": driver_id,
                "evm_address": evm_address,
                "reward_weight": reward_weight,
                "packets": 1,
            },
            trip_fare_usd=fare_usd,
        )

        event = {
            "telemetry_id": telemetry_id,
            "driver_id": driver_id,
            "evm_address": evm_address,
            "shard_id": shard_id,
            "reward_weight": reward_weight,
            "fare_usd": fare_usd,
            "depin_rewards_usd": earnings["depin_rewards_usd"],
            "app_earnings_usd": earnings["app_earnings_usd"],
            "signed_at": signed_at,
        }

        with self._events_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event) + "\n")

        balances = self._load_balances()
        row = balances.setdefault(
            driver_id,
            {
                "driver_id": driver_id,
                "evm_address": evm_address,
                "total_events": 0,
                "total_reward_weight": 0.0,
                "total_depin_usd": 0.0,
                "total_app_usd": 0.0,
                "last_event_at": None,
            },
        )
        row["total_events"] += 1
        row["total_reward_weight"] = round(row["total_reward_weight"] + reward_weight, 6)
        row["total_depin_usd"] = round(row["total_depin_usd"] + earnings["depin_rewards_usd"], 6)
        row["total_app_usd"] = round(row["total_app_usd"] + earnings["app_earnings_usd"], 6)
        row["last_event_at"] = signed_at
        self._save_balances(balances)
        return event

    def contribution_summary(
        self,
        driver_id: str,
        pipeline_stats: dict[str, Any] | None,
        *,
        trip_fare_usd: float = 0.0,
    ) -> ContributionSummary:
        balances = self._load_balances().get(driver_id, {})
        stats = pipeline_stats or {}
        earnings = estimate_rewards(stats, trip_fare_usd=trip_fare_usd)

        return ContributionSummary(
            driver_id=driver_id,
            evm_address=stats.get("evm_address") or balances.get("evm_address", ""),
            total_packets=int(stats.get("packets", 0)),
            total_distance_km=float(stats.get("distance_km", 0.0)),
            total_drive_seconds=int(stats.get("drive_seconds", 0)),
            mandelbrot_nodes=int(stats.get("mandelbrot_nodes", 0)),
            estimated_rewards_usd=float(earnings["estimated_total_usd"]),
            app_earnings_usd=float(earnings["app_earnings_usd"]),
            depin_rewards_usd=float(earnings["depin_rewards_usd"]),
            last_contribution_at=stats.get("last_contribution_at"),
        )

    def driver_balance(self, driver_id: str) -> dict[str, Any] | None:
        return self._load_balances().get(driver_id)

    def leaderboard(self, limit: int = 25) -> list[dict[str, Any]]:
        rows = list(self._load_balances().values())
        rows.sort(key=lambda row: row.get("total_reward_weight", 0.0), reverse=True)
        return rows[:limit]

    def _load_balances(self) -> dict[str, Any]:
        if not self._balances_path.exists():
            return {}
        return json.loads(self._balances_path.read_text(encoding="utf-8"))

    def _save_balances(self, balances: dict[str, Any]) -> None:
        self._balances_path.write_text(json.dumps(balances, indent=2), encoding="utf-8")

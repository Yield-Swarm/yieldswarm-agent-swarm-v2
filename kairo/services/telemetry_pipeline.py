"""Full pipeline: collect → sign → verify → Mandelbrot → rewards → YieldSwarm."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from kairo.models.driver import SignedTelemetry
from kairo.models.telemetry_packet import DriverTelemetrySample
from kairo.services.earnings import estimate_rewards
from kairo.services.identity import DriverStore
from kairo.services.mandelbrot_pipeline import MandelbrotPipeline
from kairo.services.reward_ledger import RewardLedger
from kairo.services.signing import sign_telemetry, verify_telemetry
from kairo.services.yieldswarm_emitter import YieldSwarmEmitter


class TelemetryPipeline:
    """Orchestrates signed driver telemetry into the YieldSwarm Mandelbrot layer."""

    def __init__(
        self,
        store_dir: Path | None = None,
        *,
        emit_yieldswarm: bool | None = None,
    ) -> None:
        root = store_dir or Path(os.environ.get("KAIRO_STORE_DIR", ".data/kairo"))
        self.drivers = DriverStore(root)
        self.mandelbrot = MandelbrotPipeline(root)
        self.rewards = RewardLedger(root)
        self._emit_yieldswarm = (
            emit_yieldswarm
            if emit_yieldswarm is not None
            else os.environ.get("KAIRO_EMIT_YIELDSWARM", "true").lower() in ("1", "true", "yes")
        )
        self._emitter = YieldSwarmEmitter() if self._emit_yieldswarm else None

    def collect_sample(self, raw: dict[str, Any]) -> DriverTelemetrySample:
        """Normalize raw device telemetry into a DriverTelemetrySample."""
        driver_id = raw["driver_id"]
        identity = self.drivers.get(driver_id)
        if not identity:
            raise KeyError(f"unknown driver: {driver_id}")

        sample = DriverTelemetrySample.from_dict(
            {
                **raw,
                "evm_address": identity.evm_address,
            }
        )
        return sample

    def sign_sample(self, sample: DriverTelemetrySample) -> SignedTelemetry:
        """Sign a telemetry sample with the driver's stored identity."""
        identity = self.drivers.get(sample.driver_id)
        if not identity:
            raise KeyError(f"unknown driver: {sample.driver_id}")
        return sign_telemetry(identity, sample.to_payload())

    def process_sample(self, raw: dict[str, Any]) -> dict[str, Any]:
        """Collect, sign, route, and record rewards for one telemetry sample."""
        sample = self.collect_sample(raw)
        packet = self.sign_sample(sample)
        return self.ingest_signed_packet(packet, fare_usd=sample.fare_usd)

    def ingest_signed_packet(
        self,
        packet: SignedTelemetry | dict[str, Any],
        *,
        fare_usd: float = 0.0,
    ) -> dict[str, Any]:
        """Verify signature, route to Mandelbrot, update rewards, optionally emit."""
        row = packet if isinstance(packet, dict) else packet.to_dict()
        driver_id = row["driver_id"]
        identity = self.drivers.get(driver_id)
        if not identity:
            raise KeyError(f"unknown driver: {driver_id}")

        signed = packet if isinstance(packet, SignedTelemetry) else SignedTelemetry(**row)
        if not verify_telemetry(signed, identity.public_key_hex):
            raise ValueError("invalid telemetry signature")

        record = self.mandelbrot.ingest(signed)
        tree = record["tree"]
        reward_event = self.rewards.record(
            driver_id=driver_id,
            evm_address=identity.evm_address,
            telemetry_id=record["telemetry_id"],
            reward_weight=float(tree["reward_weight"]),
            shard_id=int(tree["shard_id"]),
            fare_usd=fare_usd or float(row.get("payload", {}).get("fare_usd", 0)),
            signed_at=record["signed_at"],
        )

        harvest_path = None
        if self._emitter:
            harvest_path = self._emitter.emit(record)

        stats = self.mandelbrot.driver_stats(driver_id) or {}
        summary = self.rewards.contribution_summary(driver_id, stats, trip_fare_usd=fare_usd)

        return {
            "accepted": True,
            "telemetry_id": record["telemetry_id"],
            "shard_id": tree["shard_id"],
            "mandelbrot_score": tree["mandelbrot_score"],
            "reward_weight": tree["reward_weight"],
            "reward_event": reward_event,
            "contribution": summary.to_dict(),
            "harvest_path": harvest_path,
            "tree": tree,
        }

    def submit(
        self,
        body: dict[str, Any],
        *,
        pre_signed: bool = False,
    ) -> dict[str, Any]:
        """HTTP-friendly entry: unsigned payload or pre-signed packet."""
        driver_id = body["driver_id"]

        if pre_signed or "signature" in body:
            packet = SignedTelemetry(
                driver_id=driver_id,
                evm_address=body.get("evm_address", ""),
                payload=body["payload"],
                signature=body["signature"],
                signed_at=body.get("signed_at", ""),
                telemetry_id=body.get("telemetry_id", ""),
            )
            if not packet.evm_address:
                identity = self.drivers.get(driver_id)
                if identity:
                    packet.evm_address = identity.evm_address
            return self.ingest_signed_packet(
                packet,
                fare_usd=float(body.get("fare_usd", 0) or body.get("payload", {}).get("fare_usd", 0)),
            )

        return self.process_sample(body)

    def process_batch(self, samples: list[dict[str, Any]]) -> dict[str, Any]:
        results = []
        errors = []
        for raw in samples:
            try:
                results.append(self.process_sample(raw))
            except (KeyError, ValueError) as exc:
                errors.append({"driver_id": raw.get("driver_id"), "error": str(exc)})
        return {"accepted": len(results), "failed": len(errors), "results": results, "errors": errors}

    def contribution(self, driver_id: str, trip_fare_usd: float = 0.0) -> dict[str, Any]:
        stats = self.mandelbrot.driver_stats(driver_id)
        if not stats:
            return {
                "driver_id": driver_id,
                "packets": 0,
                "estimated_total_usd": 0.0,
                "app_earnings_usd": 0.0,
                "depin_rewards_usd": 0.0,
            }
        summary = self.rewards.contribution_summary(driver_id, stats, trip_fare_usd=trip_fare_usd)
        earnings = estimate_rewards(stats, trip_fare_usd=trip_fare_usd)
        return {**summary.to_dict(), **earnings}

    def leaderboard(self, limit: int = 25) -> dict[str, Any]:
        rows = self.mandelbrot.all_driver_stats()
        ranked = sorted(rows, key=lambda row: row.get("reward_weight", 0.0), reverse=True)
        return {
            "drivers": [estimate_rewards(row) for row in ranked[:limit]],
            "reward_balances": self.rewards.leaderboard(limit),
            "tree": self.mandelbrot.tree_summary(),
        }

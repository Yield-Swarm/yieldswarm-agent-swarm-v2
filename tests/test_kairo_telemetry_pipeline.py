"""Tests for Kairo telemetry pipeline — collect, sign, Mandelbrot, rewards."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from kairo.client.telemetry import DriverTelemetryClient
from kairo.services.identity import DriverStore, generate_driver_identity
from kairo.services.telemetry_pipeline import TelemetryPipeline


class TelemetryPipelineTests(unittest.TestCase):
    def test_full_pipeline_collect_sign_route_reward(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pipeline = TelemetryPipeline(root, emit_yieldswarm=True)
            identity = generate_driver_identity("driver-pipeline-1")
            pipeline.drivers.save(identity)

            result = pipeline.process_sample(
                {
                    "driver_id": "driver-pipeline-1",
                    "latitude": 39.7392,
                    "longitude": -104.9903,
                    "speed_kmh": 42.0,
                    "distance_km": 3.5,
                    "duration_seconds": 300,
                    "fare_usd": 18.5,
                }
            )

            self.assertTrue(result["accepted"])
            self.assertIn("shard_id", result)
            self.assertGreater(result["reward_weight"], 0)
            self.assertIsNotNone(result["harvest_path"])
            self.assertTrue(Path(result["harvest_path"]).exists())

            contribution = pipeline.contribution("driver-pipeline-1", trip_fare_usd=18.5)
            self.assertEqual(contribution["total_packets"], 1)
            self.assertGreater(contribution["depin_rewards_usd"], 0)
            self.assertEqual(contribution["app_earnings_usd"], 37.0)

    def test_batch_processing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            pipeline = TelemetryPipeline(Path(tmp), emit_yieldswarm=False)
            identity = generate_driver_identity("batch-driver")
            pipeline.drivers.save(identity)

            batch = pipeline.process_batch(
                [
                    {"driver_id": "batch-driver", "latitude": 39.7, "longitude": -104.9, "speed_kmh": 30},
                    {"driver_id": "batch-driver", "latitude": 39.71, "longitude": -104.91, "speed_kmh": 32},
                ]
            )
            self.assertEqual(batch["accepted"], 2)
            self.assertEqual(batch["failed"], 0)

    def test_driver_client(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pipeline = TelemetryPipeline(root, emit_yieldswarm=False)
            store = DriverStore(root)
            identity = generate_driver_identity("client-driver")
            store.save(identity)

            client = DriverTelemetryClient("client-driver", pipeline=pipeline)
            sample = client.collect(39.74, -104.99, speed_kmh=25.0, distance_km=1.0)
            result = client.submit_sample(sample)
            self.assertTrue(result["accepted"])


if __name__ == "__main__":
    unittest.main()

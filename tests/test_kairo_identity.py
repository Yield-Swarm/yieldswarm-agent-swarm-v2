"""Tests for Kairo cryptographic identity and telemetry pipeline."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from kairo.services.earnings import estimate_rewards
from kairo.services.identity import DriverStore, generate_driver_identity
from kairo.services.mandelbrot_pipeline import MandelbrotPipeline
from kairo.services.signing import sign_telemetry, verify_telemetry


class KairoIdentityTests(unittest.TestCase):
    def test_identity_addresses(self) -> None:
        identity = generate_driver_identity("test-driver")
        self.assertTrue(identity.evm_address.startswith("0x"))
        self.assertTrue(identity.iotex_address.startswith("io1"))
        self.assertEqual(len(identity.evm_address), 42)

    def test_sign_and_verify_telemetry(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = DriverStore(Path(tmp) / "drivers")
            pipeline = MandelbrotPipeline(Path(tmp) / "pipeline")
            identity = generate_driver_identity("driver-1")
            store.save(identity)

            payload = {
                "latitude": 39.7,
                "longitude": -104.9,
                "speed_kmh": 35.0,
                "distance_km": 2.5,
                "duration_seconds": 200,
            }
            packet = sign_telemetry(identity, payload)
            self.assertTrue(verify_telemetry(packet, identity.public_key_hex))

            record = pipeline.ingest(packet)
            self.assertIn("tree", record)
            self.assertEqual(record["driver_id"], "driver-1")

            stats = pipeline.driver_stats("driver-1")
            assert stats is not None
            earnings = estimate_rewards(stats, trip_fare_usd=20.0)
            self.assertEqual(earnings["app_earnings_usd"], 40.0)
            self.assertEqual(earnings["customer_fee_usd"], 0.2)
            self.assertGreater(earnings["depin_rewards_usd"], 0)


if __name__ == "__main__":
    unittest.main()

"""Tests for Neon telemetry store (file fallback — no live DATABASE_URL required)."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from services import neon_store


class NeonStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self._prev_url = os.environ.pop("DATABASE_URL", None)
        os.environ["NEON_FALLBACK_DIR"] = self._tmpdir.name
        os.environ["NEON_LOG_ENABLED"] = "true"

    def tearDown(self) -> None:
        if self._prev_url is not None:
            os.environ["DATABASE_URL"] = self._prev_url
        self._tmpdir.cleanup()

    def test_log_mandelbrot_file_fallback(self) -> None:
        record = {
            "telemetry_id": "tel_test_001",
            "driver_id": "driver-neon-1",
            "evm_address": "0xabc",
            "signed_at": "2026-06-16T00:00:00Z",
            "payload": {"latitude": 39.7, "longitude": -104.9},
            "tree": {
                "shard_id": 42,
                "branch": 10,
                "leaf": 20,
                "mandelbrot_score": 18,
                "reward_weight": 12.5,
                "speed_kmh": 35.0,
            },
        }
        result = neon_store.log_mandelbrot(record)
        self.assertTrue(result["ok"])
        self.assertEqual(result["sink"], "file")
        path = Path(result["path"])
        self.assertTrue(path.exists())
        row = json.loads(path.read_text(encoding="utf-8").strip())
        self.assertEqual(row["telemetry_id"], "tel_test_001")
        self.assertEqual(row["mandelbrot_score"], 18)

    def test_log_helix_file_fallback(self) -> None:
        snapshot = {
            "service": "helix-chain",
            "activated": True,
            "phase": "genesis-active",
            "genesisHash": "abc123",
            "readinessScore": "6/8",
            "yslr": {"phase": "listening"},
            "sovereign": {"progress": 0.42},
            "onChainReceipts": {"treasuryNavUsd": 1_250_000},
        }
        result = neon_store.log_helix(snapshot)
        self.assertTrue(result["ok"])
        self.assertEqual(result["sink"], "file")
        counts = neon_store.recent_counts()
        self.assertEqual(counts["helix_chain_snapshots"], 1)
        self.assertEqual(counts["mandelbrot_telemetry"], 0)


if __name__ == "__main__":
    unittest.main()

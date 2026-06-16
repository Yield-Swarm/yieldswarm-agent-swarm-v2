"""Tests for the unified sovereign runtime (heal + treasury + state load)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "iteration-100"))


class TestStateLoad(unittest.TestCase):
    def test_roundtrip_snapshot(self):
        from core.state import AkashWorker, SovereignState, YieldStrategy, from_snapshot, persist, load

        state = SovereignState(
            tick=42,
            vault_usd=10_000.0,
            target_apy=0.30,
            workers=[AkashWorker(
                dseq="123",
                provider="akash1test",
                gpu_model="RTX3090",
                hourly_cost_usd=0.28,
                hourly_revenue_usd=0.40,
                uptime=0.99,
                health=0.95,
                credits_usd=200.0,
            )],
            strategies=[YieldStrategy("Core", 1000.0, 0.10, 0.1, True, 0.08)],
        )

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state.json"
            persist(state, str(path))
            restored = load(str(path))
            self.assertIsNotNone(restored)
            assert restored is not None
            self.assertEqual(restored.tick, 42)
            self.assertEqual(len(restored.workers), 1)
            self.assertEqual(restored.workers[0].dseq, "123")
            self.assertAlmostEqual(restored.vault_usd, 10_000.0)

    def test_from_snapshot_strips_roi(self):
        from core.state import from_snapshot

        snap = {
            "tick": 1,
            "workers": [{
                "dseq": "1",
                "provider": "p",
                "gpu_model": "H100",
                "hourly_cost_usd": 1.0,
                "hourly_revenue_usd": 2.0,
                "uptime": 1.0,
                "health": 1.0,
                "credits_usd": 50.0,
                "roi": 1.0,
            }],
            "agents": [{"agent_id": "a1", "genome": {}, "assigned_workers": 3}],
            "strategies": [],
        }
        state = from_snapshot(snap)
        self.assertEqual(state.workers[0].dseq, "1")
        self.assertEqual(state.agents[0].assigned_workers, [])


class TestLiveTreasury(unittest.TestCase):
    def test_great_delta_split_sums_to_total(self):
        from services.live_treasury import FALLBACK_TREASURY_USD, _split_usd

        splits = _split_usd(FALLBACK_TREASURY_USD)
        total = sum(row["usd"] for row in splits)
        self.assertAlmostEqual(total, FALLBACK_TREASURY_USD, places=1)
        self.assertEqual(len(splits), 4)

    def test_policy_rebalance_detects_drift(self):
        from services.live_treasury import TreasuryOverlay, compute_policy_rebalance

        overlay = TreasuryOverlay(
            source="test",
            live=False,
            total_usd=1_000_000.0,
            splits=[
                {"bucket": "coreTreasury", "label": "Core", "bps": 5000, "usd": 700_000},
                {"bucket": "growthTreasury", "label": "Growth", "bps": 3000, "usd": 150_000},
                {"bucket": "insuranceTreasury", "label": "Insurance", "bps": 1500, "usd": 100_000},
                {"bucket": "opsTreasury", "label": "Ops", "bps": 500, "usd": 50_000},
            ],
        )
        actions, moved = compute_policy_rebalance(overlay)
        self.assertGreater(len(actions), 0)
        self.assertGreater(moved, 0)

    def test_overlay_to_strategies(self):
        from services.live_treasury import TreasuryOverlay, overlay_to_strategies

        overlay = TreasuryOverlay(
            source="test",
            live=False,
            total_usd=100_000.0,
            splits=[{"bucket": "coreTreasury", "label": "Core", "bps": 5000, "usd": 50_000}],
        )
        strategies = overlay_to_strategies(overlay)
        self.assertEqual(len(strategies), 1)
        self.assertEqual(strategies[0].allocation_usd, 50_000.0)


class TestLiveAkashHeal(unittest.TestCase):
    def test_heal_skips_without_lease_env(self):
        from services.live_akash_heal import heal_cycle

        report = heal_cycle(run_shell=False)
        self.assertFalse(report.ran)

    def test_actions_from_output(self):
        from services.live_akash_heal import _actions_from_output

        output = "escrow topped up\nworkers healthy\nlease inactive"
        actions = _actions_from_output(output)
        kinds = {a.action for a in actions}
        self.assertIn("topup", kinds)
        self.assertIn("health_ok", kinds)
        self.assertIn("lease_inactive", kinds)


class TestSovereignRuntime(unittest.TestCase):
    def test_single_cycle_writes_state(self):
        from services.sovereign_runtime import SovereignRuntime

        with tempfile.TemporaryDirectory() as tmp:
            state_path = Path(tmp) / "state.json"
            dash_path = Path(tmp) / "dash.md"
            runtime = SovereignRuntime(
                state_path=state_path,
                dashboard_path=dash_path,
                resume=False,
            )
            report = runtime.run_cycle()
            self.assertGreater(report["tick"], 0)
            self.assertTrue(state_path.is_file())
            self.assertTrue(dash_path.is_file())
            data = json.loads(state_path.read_text(encoding="utf-8"))
            self.assertEqual(data["tick"], report["tick"])


if __name__ == "__main__":
    unittest.main()

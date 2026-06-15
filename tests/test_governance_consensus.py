"""Tests for 100-model Kimiclaw governance consensus."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from agents.governance.consensus_engine import GovernanceConsensusEngine, run_governance_consensus
from agents.governance.gospel import CONSENSUS_THRESHOLD, GOVERNANCE_MODEL_COUNT


class GovernanceConsensusTests(unittest.TestCase):
    def test_builds_100_models(self) -> None:
        engine = GovernanceConsensusEngine(seed=100)
        models = engine.build_models()
        self.assertEqual(GOVERNANCE_MODEL_COUNT, len(models))
        seats = {model.council_seat for model in models}
        self.assertEqual(14, len(seats))

    def test_deterministic_consensus(self) -> None:
        engine = GovernanceConsensusEngine(seed=42)
        first = engine.run("test proposal alpha")
        second = engine.run("test proposal alpha")
        self.assertEqual(first.approve_count, second.approve_count)
        self.assertEqual(first.council_approvals, second.council_approvals)
        self.assertEqual(first.kimiclaw_signature, second.kimiclaw_signature)

    def test_threshold_structure(self) -> None:
        engine = GovernanceConsensusEngine(seed=100)
        report = engine.run("Council Wishlist integration wiring")
        self.assertLessEqual(report.council_approvals, 14)
        self.assertGreaterEqual(report.council_approvals, 0)
        if report.threshold_met:
            self.assertGreaterEqual(report.council_approvals, CONSENSUS_THRESHOLD[0])

    def test_run_persists_report(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "report.json"
            with unittest.mock.patch.dict(os.environ, {"KIMICLAW_CONSENSUS_KEY": "test-key"}):
                payload = run_governance_consensus(
                    "persist test",
                    output_path=out,
                    model_count=100,
                    seed=100,
                )
            self.assertTrue(out.exists())
            self.assertEqual(100, payload["model_count"])
            self.assertIn("consensus", payload)
            self.assertIn("kimiclaw_signature", payload)


if __name__ == "__main__":
    import unittest.mock  # noqa: E402

    unittest.main()

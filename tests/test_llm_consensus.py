"""Tests for live LLM consensus engine (offline / gospel fallback)."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from agents.governance.llm_consensus_engine import (
    LlmConsensusEngine,
    _parse_vote_json,
    list_active_voters,
    run_llm_consensus,
)


class LlmConsensusTests(unittest.TestCase):
    def test_parse_vote_json_with_fence(self) -> None:
        raw = '```json\n{"vote":"approve","chosen_option_id":"a","confidence":0.9,"rationale":"ok"}\n```'
        parsed = _parse_vote_json(raw)
        self.assertEqual("approve", parsed["vote"])
        self.assertEqual("a", parsed["chosen_option_id"])

    def test_list_active_voters_includes_gospel(self) -> None:
        voters = list_active_voters()
        ids = {v["id"] for v in voters}
        self.assertIn("gospel-council-sim", ids)

    def test_run_consensus_gospel_fallback(self) -> None:
        options = [
            {"id": "alpha", "label": "Alpha step"},
            {"id": "beta", "label": "Beta step"},
        ]
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "report.json"
            payload = run_llm_consensus(
                context="Council integration wiring test",
                options=options,
                output_path=out,
            )
            self.assertTrue(out.exists())
            self.assertIn("consensus", payload)
            self.assertGreaterEqual(payload["simulated_voter_count"], 1)
            self.assertIn("votes", payload)

    def test_engine_threshold_structure(self) -> None:
        engine = LlmConsensusEngine(max_workers=2)
        report = engine.run_next_step(
            context="governance proposal for helix deploy",
            options=[{"id": "deploy", "label": "Deploy"}],
            proposal="wire council integrations",
        )
        self.assertLessEqual(report.council_approvals, 14)
        data = report.to_dict()
        self.assertEqual("next_step", data["mode"])


if __name__ == "__main__":
    unittest.main()

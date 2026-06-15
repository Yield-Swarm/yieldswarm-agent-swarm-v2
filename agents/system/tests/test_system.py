"""Tests for the Arena mutation stack."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from agents.system.constants import DEITY_MANIFEST_COUNT, TOTAL_CHARTING_AGENTS
from agents.system.deity_manifests import ensure_deity_manifests, load_deity_manifests
from agents.system.engine import MutatedChartingEngine


class ArenaSystemTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name) / "agents"

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_manifest_generation_count(self) -> None:
        ensure_deity_manifests(self.root)
        manifests = load_deity_manifests(self.root)
        self.assertEqual(DEITY_MANIFEST_COUNT, len(manifests))

    def test_engine_spawns_all_agents(self) -> None:
        engine = MutatedChartingEngine(self.root)
        self.assertEqual(TOTAL_CHARTING_AGENTS, len(engine.agents))

    def test_mutation_and_archive(self) -> None:
        engine = MutatedChartingEngine(self.root)
        target = "chart-agent-00001"
        original_skin = engine.agents[target].metal_skin
        engine.report_performance(target, arena_score=-100.0, signal_precision=0.1, pnl_bps=-100)
        result = engine.mutate_bottom_performers(ratio=0.01, batch_size=10)
        self.assertGreater(result["mutated_agents"], 0)
        self.assertNotEqual(original_skin, engine.agents[target].metal_skin)

        archive_entry = engine.archive_snapshot(note="test")
        proof = archive_entry["proof"]
        state_hash = archive_entry["state_hash"]
        self.assertTrue(engine.archive.verify(state_hash, proof))

        archive_file = self.root / "system" / "archive" / "zk-archive.jsonl"
        lines = archive_file.read_text(encoding="utf-8").strip().splitlines()
        self.assertGreaterEqual(len(lines), 1)
        last_record = json.loads(lines[-1])
        self.assertEqual(last_record["state_hash"], state_hash)


if __name__ == "__main__":
    unittest.main()

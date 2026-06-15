import tempfile
import unittest
from pathlib import Path

import sys

sys.path.append(str(Path(__file__).resolve().parents[1] / "agents"))

from odysseus_memory import OdysseusMemory, OdysseusMemoryConfig, build_agent_id


class OdysseusMemoryTests(unittest.TestCase):
    def make_memory(self, root: Path, node_id: str) -> OdysseusMemory:
        return OdysseusMemory(
            OdysseusMemoryConfig(
                chroma_mode="jsonl",
                persist_dir=str(root / "chroma"),
                node_id=node_id,
                sync_outbox_path=str(root / "outbox.jsonl"),
                sync_cursor_dir=str(root / "cursors"),
            )
        )

    def test_records_and_recalls_core_memory_types(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            memory = self.make_memory(Path(temp_dir), "node-a")
            agent_id = build_agent_id(7, 12)

            memory.register_agent_mesh()
            memory.record_mutation(
                agent_id=agent_id,
                shard_id=7,
                mutation={"type": "strategy_mutation", "strategy": "akash rebalance"},
                outcome={"roi_delta": 0.12},
            )
            memory.record_performance(
                agent_id=agent_id,
                shard_id=7,
                metric_name="roi_delta",
                metric_value=0.12,
            )
            memory.upsert_deity_identity(
                deity_id="deity-001",
                name="Kimiclaw",
                role="head_of_consensus_council",
                authority="9/14 threshold lead",
                council_seat=1,
            )
            memory.record_cross_agent_learning(
                source_agent_id=agent_id,
                summary="Akash rebalance improved ROI for shard 7.",
            )

            results = memory.recall("Akash rebalance", limit=10)

            collections = {result["collection"] for result in results}
            self.assertIn("agent_mutations", collections)
            self.assertIn("performance_history", collections)
            self.assertIn("cross_agent_learnings", collections)

    def test_import_sync_payload_replays_remote_events(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            memory_a = self.make_memory(root / "a", "node-a")
            memory_b = self.make_memory(root / "b", "node-b")

            memory_a.record_cross_agent_learning(
                source_agent_id=build_agent_id(0, 1),
                summary="Pool migration should be shared across worker nodes.",
                confidence=0.9,
            )

            payload = memory_a.build_sync_payload()
            imported = memory_b.import_sync_payload(payload)
            results = memory_b.recall("Pool migration", limit=5)

            self.assertEqual(imported, 1)
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["collection"], "cross_agent_learnings")


if __name__ == "__main__":
    unittest.main()

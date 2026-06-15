"""Tests for Odysseus central brain."""

from __future__ import annotations

import os
import unittest

os.environ.setdefault("ODYSSEUS_API_KEY", "test-key")
os.environ.setdefault("YIELDSWARM_ROUTER_API_KEY", "test-router")
os.environ.setdefault("ODYSSEUS_CHROMA_MODE", "jsonl")

from services.odysseus.brain import OdysseusBrain  # noqa: E402


class OdysseusBrainTests(unittest.TestCase):
    def test_bootstrap_registers_tools(self) -> None:
        brain = OdysseusBrain()
        status = brain.bootstrap()
        self.assertIn("yieldswarm_akash_lease", status.registered_tools)
        self.assertEqual(status.status, "ready")

    def test_model_routing_sync(self) -> None:
        brain = OdysseusBrain()
        routing = brain.sync_model_routing()
        self.assertIn("recommendations", routing)
        self.assertIn("preferred_models", routing)

    def test_telemetry_shape(self) -> None:
        brain = OdysseusBrain()
        brain.bootstrap()
        telemetry = brain.telemetry()
        self.assertIn("agents", telemetry)
        self.assertIn("memory", telemetry)
        self.assertEqual(telemetry["source"], "odysseus-brain")


if __name__ == "__main__":
    unittest.main()

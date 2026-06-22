"""Tests for Google Antigravity sovereign handler (no live API calls)."""

from __future__ import annotations

import unittest

from services.intelligence.antigravity_core import (
    YieldSwarmAntigravityConfig,
    _is_destructive_command,
    build_yieldswarm_policies,
    is_antigravity_available,
)


@unittest.skipUnless(is_antigravity_available(), "google-antigravity not installed")
class AntigravityCoreTests(unittest.TestCase):
    def test_destructive_command_detection(self) -> None:
        self.assertTrue(_is_destructive_command({"CommandLine": "rm -rf /var"}))
        self.assertTrue(_is_destructive_command({"command": "sudo rm -fr data"}))
        self.assertFalse(_is_destructive_command({"CommandLine": "nvidia-smi"}))
        self.assertFalse(_is_destructive_command({"CommandLine": "ls -la"}))

    def test_policy_list_non_empty(self) -> None:
        policies = build_yieldswarm_policies()
        self.assertGreaterEqual(len(policies), 3)

    def test_config_from_env_builds_local_config(self) -> None:
        cfg = YieldSwarmAntigravityConfig.from_env()
        local = cfg.build_local_config()
        self.assertIn("YieldSwarm", local.system_instructions)
        self.assertTrue(cfg.high_reasoning)

    def test_handler_status_shape(self) -> None:
        from services.intelligence.antigravity_core import SovereignAntigravityHandler

        handler = SovereignAntigravityHandler()
        status = handler.status()
        self.assertEqual(status["runtime"], "google-antigravity")
        self.assertEqual(status["sdk"], "official")


if __name__ == "__main__":
    unittest.main()

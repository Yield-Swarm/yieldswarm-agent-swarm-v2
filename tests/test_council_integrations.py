"""Tests for Council Wishlist integration wiring."""

from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from services.integrations.config import CouncilIntegrationConfig, load_council_config
from services.integrations.registry import check_all_integrations


class CouncilIntegrationsTests(unittest.TestCase):
    def test_load_config_without_secrets(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            cfg = load_council_config()
        self.assertEqual(cfg.configured_services, ())

    def test_configured_services_detection(self) -> None:
        env = {
            "QUICKNODE_API_KEY": "qn-test",
            "QUICKNODE_RPC_URL": "https://example.quicknode.com",
            "SENTRY_DSN": "https://example@sentry.io/1",
            "PINATA_JWT": "jwt-test",
        }
        with patch.dict(os.environ, env, clear=True):
            cfg = load_council_config()
        self.assertIn("quicknode", cfg.configured_services)
        self.assertIn("sentry", cfg.configured_services)
        self.assertIn("pinata", cfg.configured_services)
        self.assertNotIn("livepeer", cfg.configured_services)

    def test_registry_skips_livepeer(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            report = check_all_integrations(init_observability=False)
        self.assertTrue(report["livepeer_skipped"])
        self.assertEqual(report["services"]["livepeer"]["skipped"], True)

    def test_public_config_has_no_secrets(self) -> None:
        cfg = CouncilIntegrationConfig(
            quicknode_api_key="secret",
            sentry_dsn="https://secret@sentry.io/1",
            configured_services=("quicknode", "sentry"),
        )
        public = cfg.to_public()
        self.assertNotIn("secret", str(public))
        self.assertIn("quicknode", public["configured_services"])


if __name__ == "__main__":
    unittest.main()

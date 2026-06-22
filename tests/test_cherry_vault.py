"""Tests for Cherry Servers Vault client."""

from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from services.infra.cherry_vault import get_cherry_api_key, mask_api_key


class CherryVaultTests(unittest.TestCase):
    def setUp(self):
        get_cherry_api_key.cache_clear()

    def tearDown(self):
        get_cherry_api_key.cache_clear()
        os.environ.pop("CHERRY_SERVERS_API_KEY", None)

    def test_mask(self):
        self.assertEqual(mask_api_key("abcdefgh1234"), "abcdefgh…")

    @patch("services.infra.cherry_vault._read_kv_path")
    def test_reads_cloud_cherry_first(self, mock_read):
        def side_effect(_mount, path):
            if path == "cloud/cherry":
                return {"api_key": "cloud-key"}
            return {}

        mock_read.side_effect = side_effect
        self.assertEqual(get_cherry_api_key(), "cloud-key")

    @patch("services.infra.cherry_vault._read_kv_path", return_value={})
    def test_env_fallback(self, _mock_read):
        os.environ["CHERRY_SERVERS_API_KEY"] = "env-cherry-key"
        self.assertEqual(get_cherry_api_key(), "env-cherry-key")


if __name__ == "__main__":
    unittest.main()

"""Unit tests for Alchemy Vault client (no real secrets)."""

from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from services.alchemy.vault_client import get_alchemy_api_key, mask_api_key


class AlchemyVaultClientTests(unittest.TestCase):
    def setUp(self):
        get_alchemy_api_key.cache_clear()

    def tearDown(self):
        get_alchemy_api_key.cache_clear()
        os.environ.pop("ALCHEMY_API_KEY", None)
        os.environ.pop("ALCHEMY_KEY_PREFIX_HINT", None)

    def test_mask_api_key(self):
        self.assertEqual(mask_api_key("abcdefghijklmnop"), "abcdefghijkl…")
        self.assertEqual(mask_api_key(""), "(unset)")

    @patch("services.alchemy.vault_client._read_kv_path")
    def test_reads_from_vault_rpc_ethereum(self, mock_read):
        mock_read.return_value = {"alchemy_api_key": "vault-test-key-xyz"}
        self.assertEqual(get_alchemy_api_key(), "vault-test-key-xyz")

    @patch("services.alchemy.vault_client._read_kv_path", return_value={})
    def test_falls_back_to_env(self, _mock_read):
        os.environ["ALCHEMY_API_KEY"] = "env-only-key"
        self.assertEqual(get_alchemy_api_key(), "env-only-key")

    @patch("services.alchemy.vault_client._read_kv_path", return_value={})
    @patch("services.alchemy.vault_client.load_runtime_secrets")
    def test_raises_when_missing(self, mock_runtime, _mock_read):
        from lib.secrets import RuntimeSecrets

        mock_runtime.return_value = RuntimeSecrets()
        with self.assertRaises(RuntimeError):
            get_alchemy_api_key()


if __name__ == "__main__":
    unittest.main()

"""Tests for Alchemy Rolodex client."""

from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from services.alchemy.client import AlchemyRolodex
from services.alchemy.manifest import get_network, list_networks


class AlchemyClientTests(unittest.TestCase):
    def test_manifest_loads_networks(self):
        nets = list_networks()
        self.assertGreater(len(nets), 50)
        eth = get_network("ethereum-mainnet")
        self.assertEqual(eth.family, "evm")
        self.assertEqual(eth.chain_id, 1)

    def test_build_url_no_key_in_manifest(self):
        rolodex = AlchemyRolodex(api_key="test-key-abc", require_key=False)
        url = rolodex.rpc_url("ethereum-mainnet")
        self.assertIn("eth-mainnet.g.alchemy.com", url)
        self.assertIn("test-key-abc", url)
        self.assertNotIn("API_KEY", url)

    def test_starknet_url_pattern(self):
        rolodex = AlchemyRolodex(api_key="sk-key", require_key=False)
        url = rolodex.rpc_url("starknet-mainnet")
        self.assertIn("/starknet/version/rpc/v0_10/", url)

    @patch("services.alchemy.client.get_alchemy_api_key", return_value="vault-key")
    def test_apply_env_defaults(self, _mock):
        os.environ.pop("ETHEREUM_RPC_URL", None)
        rolodex = AlchemyRolodex()
        applied = rolodex.apply_env_defaults()
        self.assertIn("ETHEREUM_RPC_URL", applied)
        self.assertIn("vault-key", os.environ["ETHEREUM_RPC_URL"])
        os.environ.pop("ETHEREUM_RPC_URL", None)


if __name__ == "__main__":
    unittest.main()

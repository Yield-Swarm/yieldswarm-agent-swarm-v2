"""Unit tests for RPC probe helpers (mocked HTTP)."""

from __future__ import annotations

import json
import unittest
from unittest.mock import patch

from services.alchemy.rpc_probes import probe_evm, with_retries


class RpcProbeTests(unittest.TestCase):
    @patch("services.alchemy.rpc_probes._http_json_rpc")
    def test_probe_evm_success(self, mock_http):
        responses = [
            ({"result": "0x1"}, 50.0),
            ({"result": "0x10"}, 40.0),
            ({"result": "0x11"}, 35.0),
            ({"result": "0x0"}, 30.0),
            ({"result": "0x12"}, 20.0),
            ({"result": "0x13"}, 20.0),
            ({"result": "0x14"}, 20.0),
        ]
        mock_http.side_effect = responses

        outcome = probe_evm("https://example.invalid/v2/key")
        self.assertTrue(outcome.ok)
        self.assertEqual(outcome.chain_id, "0x1")
        self.assertEqual(outcome.last_block, "17")

    def test_with_retries_eventually_succeeds(self):
        calls = {"n": 0}

        def flaky() -> object:
            from services.alchemy.rpc_probes import ProbeOutcome

            calls["n"] += 1
            if calls["n"] < 2:
                return ProbeOutcome(ok=False, latency_ms=1.0, error="transient")
            return ProbeOutcome(ok=True, latency_ms=2.0, chain_id="0x1")

        result = with_retries(flaky, retries=3, backoff_base_s=0.01)
        self.assertTrue(result.ok)


if __name__ == "__main__":
    unittest.main()

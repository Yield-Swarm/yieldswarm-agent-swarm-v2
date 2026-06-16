"""Tests for cross-chain MVP (Jupiter + Uniswap V4)."""

from __future__ import annotations

import unittest

from services.cross_chain.great_delta_route import route_revenue_through_treasury
from services.cross_chain.uniswap_v4 import UniswapV4HookClient


class CrossChainMvpTests(unittest.TestCase):
    def test_treasury_split_50_30_15_5(self) -> None:
        routed = route_revenue_through_treasury(100.0, source="test")
        buckets = routed["buckets"]
        self.assertAlmostEqual(buckets["coreTreasury"], 50.0)
        self.assertAlmostEqual(buckets["growthTreasury"], 30.0)
        self.assertAlmostEqual(buckets["insuranceTreasury"], 15.0)
        self.assertAlmostEqual(buckets["opsTreasury"], 5.0)

    def test_uniswap_auction_simulation(self) -> None:
        client = UniswapV4HookClient()
        result = client.simulate_auction(
            pool_id="0x" + "aa" * 32,
            bid_amount_wei=10**18,
            bidder="0x0000000000000000000000000000000000000001",
        )
        self.assertTrue(result["ok"])
        self.assertIn("won_auction", result)

    def test_dex_quote_tool_solana(self) -> None:
        from agents.yieldswarm_tools.handlers import handle_dex_quote

        result = handle_dex_quote({"chain": "solana", "amount": 1_000_000})
        self.assertIn(result["status"], {"quoted", "adapter_missing"})


if __name__ == "__main__":
    unittest.main()

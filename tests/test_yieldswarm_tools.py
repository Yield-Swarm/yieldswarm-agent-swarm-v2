import unittest

from agents.yieldswarm_tools.definitions import TOOL_DEFINITIONS, mcp_tool_schemas, openai_function_schemas
from agents.yieldswarm_tools.odysseus import register_yieldswarm_tools
from agents.yieldswarm_tools.registry import dispatch_tool


class YieldSwarmToolTests(unittest.TestCase):
    def test_schemas_are_registered_for_all_tools(self):
        function_schemas = openai_function_schemas()
        mcp_schemas = mcp_tool_schemas()

        self.assertEqual(len(function_schemas), len(TOOL_DEFINITIONS))
        self.assertEqual(len(mcp_schemas), len(TOOL_DEFINITIONS))
        self.assertEqual(
            {schema["function"]["name"] for schema in function_schemas},
            {schema["name"] for schema in mcp_schemas},
        )

    def test_odysseus_registration_populates_mutable_registries(self):
        schemas = []
        handlers = {}
        tags = {}
        descriptions = {}

        result = register_yieldswarm_tools(
            function_tool_schemas=schemas,
            tool_handlers=handlers,
            tool_tags=tags,
            builtin_tool_descriptions=descriptions,
        )

        self.assertIn("yieldswarm_treasury_rebalance", result["registered_tools"])
        self.assertIn("yieldswarm_treasury_rebalance", handlers)
        self.assertIn("yieldswarm_treasury_rebalance", tags)
        self.assertIn("yieldswarm_treasury_rebalance", descriptions)
        self.assertIn("yieldswarm_treasury_rebalance", {schema["function"]["name"] for schema in schemas})

    def test_treasury_rebalance_uses_50_30_15_5_policy(self):
        result = dispatch_tool(
            "yieldswarm_treasury_rebalance",
            {
                "mode": "simulate",
                "balances": {
                    "akash_operations": 20,
                    "dao_treasury_reserve": 40,
                    "emission_liquidity": 30,
                    "operator_rewards": 10,
                },
            },
        )

        self.assertEqual(result["status"], "simulated")
        self.assertEqual(
            result["data"]["target_balances"],
            {
                "akash_operations": 50.0,
                "dao_treasury_reserve": 30.0,
                "emission_liquidity": 15.0,
                "operator_rewards": 5.0,
            },
        )
        self.assertEqual(
            result["data"]["transfers"],
            [
                {"from": "dao_treasury_reserve", "to": "akash_operations", "amount": 10.0},
                {"from": "emission_liquidity", "to": "akash_operations", "amount": 15.0},
                {"from": "operator_rewards", "to": "akash_operations", "amount": 5.0},
            ],
        )

    def test_mutating_wallet_operations_are_dry_run_by_default(self):
        result = dispatch_tool(
            "yieldswarm_wallet_operation",
            {
                "chain": "solana",
                "operation": "send_transaction",
                "transaction": {"memo": "test"},
            },
        )

        self.assertEqual(result["status"], "dry_run")


if __name__ == "__main__":
    unittest.main()

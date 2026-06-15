"""YieldSwarm tool definitions for Odysseus-compatible agents.

The definitions in this module are intentionally framework-neutral. They can
be converted into Odysseus native function schemas or exposed through an MCP
server without duplicating schema metadata.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Mapping


JsonSchema = Dict[str, Any]


@dataclass(frozen=True)
class ToolDefinition:
    """Canonical metadata for a YieldSwarm agent tool."""

    name: str
    description: str
    input_schema: JsonSchema
    tags: tuple[str, ...]

    def as_mcp_tool(self) -> Dict[str, Any]:
        """Return the MCP tool shape used by Odysseus MCP discovery."""

        return {
            "name": self.name,
            "description": self.description,
            "inputSchema": self.input_schema,
        }

    def as_openai_function_tool(self) -> Dict[str, Any]:
        """Return the OpenAI/Odysseus function tool schema shape."""

        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.input_schema,
            },
        }


def _object(properties: Mapping[str, Any], required: Iterable[str] = ()) -> JsonSchema:
    return {
        "type": "object",
        "properties": dict(properties),
        "required": list(required),
        "additionalProperties": False,
    }


def _string(description: str, **extra: Any) -> JsonSchema:
    schema: JsonSchema = {"type": "string", "description": description}
    schema.update(extra)
    return schema


def _number(description: str, **extra: Any) -> JsonSchema:
    schema: JsonSchema = {"type": "number", "description": description}
    schema.update(extra)
    return schema


def _boolean(description: str, default: bool) -> JsonSchema:
    return {"type": "boolean", "description": description, "default": default}


TARGET_POLICY_PROPERTIES: Dict[str, Any] = {
    "akash_operations": _number("Target percentage for Akash leases, workers, and active operations."),
    "dao_treasury_reserve": _number("Target percentage for reserve treasury holdings."),
    "emission_liquidity": _number("Target percentage for APN/emission liquidity and router funding."),
    "operator_rewards": _number("Target percentage for operator, founder, or incentive distributions."),
}


TOOL_DEFINITIONS: tuple[ToolDefinition, ...] = (
    ToolDefinition(
        name="yieldswarm_akash_lease",
        description=(
            "Manage Akash leases for YieldSwarm workers: list leases, fetch lease health, "
            "top up escrow, migrate providers, or close leases. Mutating actions default to dry run."
        ),
        tags=("yieldswarm", "akash", "leases", "depin"),
        input_schema=_object(
            {
                "action": _string(
                    "Lease operation to perform.",
                    enum=["list", "get", "health", "top_up", "migrate", "close"],
                ),
                "lease_id": _string("Akash lease identifier, if known."),
                "dseq": _string("Akash deployment sequence number."),
                "gseq": _string("Akash group sequence number."),
                "oseq": _string("Akash order sequence number."),
                "owner": _string("Akash owner address for lease queries."),
                "provider": _string("Current or source provider address."),
                "target_provider": _string("Target provider address for migrations."),
                "amount_uakt": _number("Escrow top-up amount in uAKT for top_up actions.", minimum=0),
                "reason": _string("Operational reason for an action, used for audit logs."),
                "dry_run": _boolean("Preview the operation without broadcasting or mutating state.", True),
            },
            required=("action",),
        ),
    ),
    ToolDefinition(
        name="yieldswarm_treasury_rebalance",
        description=(
            "Calculate or execute YieldSwarm treasury rebalancing using the 50/30/15/5 policy: "
            "Akash operations, DAO reserve, emission liquidity, and operator rewards."
        ),
        tags=("yieldswarm", "treasury", "rebalance"),
        input_schema=_object(
            {
                "mode": _string(
                    "Whether to only inspect, simulate required transfers, or execute through the wallet SDK.",
                    enum=["inspect", "simulate", "execute"],
                ),
                "balances": {
                    "type": "object",
                    "description": "Current balances by policy bucket, in a common accounting unit.",
                    "properties": {
                        "akash_operations": _number("Current Akash operations balance."),
                        "dao_treasury_reserve": _number("Current DAO reserve balance."),
                        "emission_liquidity": _number("Current emission liquidity balance."),
                        "operator_rewards": _number("Current operator rewards balance."),
                    },
                    "additionalProperties": True,
                },
                "total_value": _number("Optional total portfolio value; inferred from balances when omitted.", minimum=0),
                "target_policy": {
                    "type": "object",
                    "description": "Override target percentages. Values must add up to 100.",
                    "properties": TARGET_POLICY_PROPERTIES,
                    "additionalProperties": False,
                },
                "asset": _string("Accounting asset or quote currency, for example USDC, AKT, APN, or USD."),
                "slippage_tolerance": _number("Maximum acceptable slippage as a decimal fraction.", minimum=0),
                "dry_run": _boolean("Preview the operation without sending wallet transactions.", True),
            },
            required=("mode",),
        ),
    ),
    ToolDefinition(
        name="yieldswarm_emission_router_query",
        description=(
            "Query on-chain emission router state for APN/Helix routes, schedules, claim windows, "
            "pending emissions, and route balances."
        ),
        tags=("yieldswarm", "emissions", "on-chain", "router"),
        input_schema=_object(
            {
                "chain": _string("Chain or network identifier, for example helix, solana, ethereum, or base."),
                "router_address": _string("Emission router contract or program address."),
                "query": _string(
                    "Router query to run.",
                    enum=["route", "schedule", "pending", "claim_window", "balances", "status"],
                ),
                "route_id": _string("Emission route identifier, if the query targets a specific route."),
                "account": _string("Wallet, vault, or beneficiary account to query."),
                "token": _string("Token mint or contract address to filter balances/emissions."),
                "block_tag": _string("Block height, slot, or tag such as latest/finalized."),
                "dry_run": _boolean("Return the query payload without calling a router endpoint.", False),
            },
            required=("chain", "query"),
        ),
    ),
    ToolDefinition(
        name="yieldswarm_wallet_operation",
        description=(
            "Perform multi-chain wallet operations through YieldSwarm's unified wallet SDK: balances, "
            "account discovery, transfer preparation, signing, and sending."
        ),
        tags=("yieldswarm", "wallet", "multi-chain"),
        input_schema=_object(
            {
                "chain": _string("Target chain, for example solana, helix, ton, zcash, ethereum, or base."),
                "operation": _string(
                    "Wallet operation to perform.",
                    enum=[
                        "list_accounts",
                        "get_address",
                        "get_balance",
                        "prepare_transfer",
                        "sign_transaction",
                        "send_transaction",
                        "sign_message",
                    ],
                ),
                "account_id": _string("Unified wallet account identifier or signer alias."),
                "asset": _string("Asset symbol, mint, or contract address."),
                "to_address": _string("Recipient address for transfer operations."),
                "amount": _number("Transfer amount in display units.", minimum=0),
                "message": _string("Message to sign for sign_message operations."),
                "transaction": {
                    "type": "object",
                    "description": "SDK-specific transaction payload for signing or sending.",
                    "additionalProperties": True,
                },
                "metadata": {
                    "type": "object",
                    "description": "Optional SDK metadata, routing hints, or memo fields.",
                    "additionalProperties": True,
                },
                "dry_run": _boolean("Prepare and validate without broadcasting.", True),
            },
            required=("chain", "operation"),
        ),
    ),
    ToolDefinition(
        name="yieldswarm_worker_telemetry",
        description=(
            "Read real-time Akash worker telemetry for leases, shards, mining jobs, and OpenClaw "
            "workers from Prometheus or a YieldSwarm telemetry endpoint."
        ),
        tags=("yieldswarm", "akash", "telemetry", "workers"),
        input_schema=_object(
            {
                "action": _string(
                    "Telemetry operation to perform.",
                    enum=["snapshot", "query", "alerts", "stream_config"],
                ),
                "lease_id": _string("Akash lease identifier to filter metrics."),
                "worker_id": _string("Worker, miner, or OpenClaw process identifier."),
                "shard_id": _string("YieldSwarm shard identifier."),
                "prometheus_query": _string("PromQL query for action=query."),
                "window": _string("Lookback or streaming window, for example 5m, 1h, or 24h."),
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of telemetry records to return.",
                    "minimum": 1,
                    "maximum": 1000,
                    "default": 100,
                },
            },
            required=("action",),
        ),
    ),
    ToolDefinition(
        name="yieldswarm_kairo_telemetry",
        description=(
            "Ingest and query Kairo driver telemetry routed through the Mandelbrot / "
            "Tree of Life mesh. Every driver is a YieldSwarm DePIN node with signed data."
        ),
        tags=("yieldswarm", "kairo", "telemetry", "depin", "mandelbrot"),
        input_schema=_object(
            {
                "action": _string(
                    "Kairo telemetry operation.",
                    enum=["ingest", "contribution", "earnings", "list_drivers"],
                ),
                "driver_id": _string("Kairo driver UUID."),
                "event": {
                    "type": "object",
                    "description": "Signed telemetry event payload for ingest action.",
                    "additionalProperties": True,
                },
                "period": _string("Earnings period (YYYY-MM) for earnings action."),
            },
            required=("action",),
        ),
    ),
)


TOOL_DEFINITIONS_BY_NAME: Dict[str, ToolDefinition] = {
    definition.name: definition for definition in TOOL_DEFINITIONS
}


def openai_function_schemas() -> List[Dict[str, Any]]:
    """Return all tool definitions as OpenAI/Odysseus function schemas."""

    return [definition.as_openai_function_tool() for definition in TOOL_DEFINITIONS]


def mcp_tool_schemas() -> List[Dict[str, Any]]:
    """Return all tool definitions as MCP tool schemas."""

    return [definition.as_mcp_tool() for definition in TOOL_DEFINITIONS]

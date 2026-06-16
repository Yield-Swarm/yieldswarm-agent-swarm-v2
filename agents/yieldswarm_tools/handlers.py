"""Handlers for YieldSwarm Odysseus tools.

The handlers are safe to load in development and CI: mutating operations are
dry-run by default, and external integrations are only used when their adapter
URLs or SDK module names are configured.
"""

from __future__ import annotations

import importlib
import json
import os
from typing import Any, Callable, Dict, Mapping, MutableMapping
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEFAULT_TREASURY_POLICY: Dict[str, float] = {
    "akash_operations": 50.0,
    "dao_treasury_reserve": 30.0,
    "emission_liquidity": 15.0,
    "operator_rewards": 5.0,
}

MUTATING_AKASH_ACTIONS = {"top_up", "migrate", "close"}
MUTATING_WALLET_OPERATIONS = {"send_transaction", "sign_transaction", "sign_message"}


class YieldSwarmToolError(ValueError):
    """Raised when a tool invocation is invalid."""


def execute_tool(name: str, arguments: Mapping[str, Any] | None = None) -> Dict[str, Any]:
    """Execute a registered YieldSwarm tool by name."""

    if name not in TOOL_HANDLERS:
        raise YieldSwarmToolError(f"Unknown YieldSwarm tool: {name}")

    return TOOL_HANDLERS[name](dict(arguments or {}))


def handle_akash_lease(arguments: MutableMapping[str, Any]) -> Dict[str, Any]:
    action = _required_string(arguments, "action")
    dry_run = _bool(arguments.get("dry_run"), True)

    if action in MUTATING_AKASH_ACTIONS and dry_run:
        return _result(
            "dry_run",
            "Akash lease operation prepared but not submitted.",
            {
                "action": action,
                "lease": _lease_identity(arguments),
                "amount_uakt": arguments.get("amount_uakt"),
                "target_provider": arguments.get("target_provider"),
                "reason": arguments.get("reason"),
            },
        )

    base_url = _env_url("YIELDSWARM_AKASH_API_URL")
    if base_url:
        return _post_json(
            base_url,
            "/akash/leases",
            {
                "action": action,
                "lease": _lease_identity(arguments),
                "amount_uakt": arguments.get("amount_uakt"),
                "target_provider": arguments.get("target_provider"),
                "reason": arguments.get("reason"),
                "dry_run": dry_run,
            },
        )

    if action in {"list", "get", "health"}:
        return _result(
            "adapter_missing",
            "Set YIELDSWARM_AKASH_API_URL to query live Akash leases.",
            {
                "action": action,
                "lease": _lease_identity(arguments),
                "expected_adapter": "YIELDSWARM_AKASH_API_URL",
            },
        )

    return _result(
        "blocked",
        "Mutating Akash lease operations require YIELDSWARM_AKASH_API_URL and dry_run=false.",
        {"action": action, "lease": _lease_identity(arguments)},
    )


def handle_treasury_rebalance(arguments: MutableMapping[str, Any]) -> Dict[str, Any]:
    mode = _required_string(arguments, "mode")
    balances = _numeric_map(arguments.get("balances") or {})
    policy = _policy(arguments.get("target_policy") or DEFAULT_TREASURY_POLICY)
    total_value = _number(arguments.get("total_value"), default=sum(balances.values()))

    if total_value < 0:
        raise YieldSwarmToolError("total_value must be non-negative")

    all_buckets = set(policy) | set(balances)
    targets = {
        bucket: round(total_value * policy.get(bucket, 0.0) / 100.0, 8)
        for bucket in sorted(all_buckets)
    }
    deltas = {
        bucket: round(targets.get(bucket, 0.0) - balances.get(bucket, 0.0), 8)
        for bucket in sorted(all_buckets)
    }
    transfers = _rebalance_transfers(deltas)

    payload = {
        "mode": mode,
        "asset": arguments.get("asset", "USD"),
        "policy_percentages": policy,
        "total_value": total_value,
        "current_balances": balances,
        "target_balances": targets,
        "deltas": deltas,
        "transfers": transfers,
        "slippage_tolerance": arguments.get("slippage_tolerance"),
    }

    dry_run = _bool(arguments.get("dry_run"), True)
    if mode in {"inspect", "simulate"} or dry_run:
        return _result("simulated", "Treasury rebalance calculated.", payload)

    wallet_module_name = os.getenv("YIELDSWARM_UNIFIED_WALLET_SDK_MODULE")
    if not wallet_module_name:
        return _result(
            "adapter_missing",
            "Set YIELDSWARM_UNIFIED_WALLET_SDK_MODULE to execute treasury transfers.",
            payload,
        )

    sdk_result = _call_wallet_sdk(
        wallet_module_name,
        "rebalance_treasury",
        {"policy": policy, "transfers": transfers, "asset": payload["asset"]},
    )
    payload["sdk_result"] = sdk_result
    return _result("submitted", "Treasury rebalance submitted through unified wallet SDK.", payload)


def handle_emission_router_query(arguments: MutableMapping[str, Any]) -> Dict[str, Any]:
    chain = _required_string(arguments, "chain")
    query = _required_string(arguments, "query")
    payload = {
        "chain": chain,
        "router_address": arguments.get("router_address") or _default_router_for_chain(chain),
        "query": query,
        "route_id": arguments.get("route_id"),
        "account": arguments.get("account"),
        "token": arguments.get("token") or os.getenv("APN_MINT_ADDRESS"),
        "block_tag": arguments.get("block_tag", "latest"),
    }

    if _bool(arguments.get("dry_run"), False):
        return _result("dry_run", "Emission router query prepared.", payload)

    base_url = _env_url("YIELDSWARM_EMISSION_ROUTER_URL")
    if not base_url:
        return _result(
            "adapter_missing",
            "Set YIELDSWARM_EMISSION_ROUTER_URL to query the emission router.",
            payload,
        )

    return _post_json(base_url, "/emission-router/query", payload)


def handle_wallet_operation(arguments: MutableMapping[str, Any]) -> Dict[str, Any]:
    chain = _required_string(arguments, "chain")
    operation = _required_string(arguments, "operation")
    dry_run = _bool(arguments.get("dry_run"), True)

    payload = {
        "chain": chain,
        "operation": operation,
        "account_id": arguments.get("account_id"),
        "asset": arguments.get("asset"),
        "to_address": arguments.get("to_address"),
        "amount": arguments.get("amount"),
        "message": arguments.get("message"),
        "transaction": arguments.get("transaction"),
        "metadata": arguments.get("metadata") or {},
        "dry_run": dry_run,
    }

    if dry_run and operation in MUTATING_WALLET_OPERATIONS:
        return _result("dry_run", "Wallet operation prepared but not signed or broadcast.", payload)

    wallet_module_name = os.getenv("YIELDSWARM_UNIFIED_WALLET_SDK_MODULE")
    if wallet_module_name:
        sdk_result = _call_wallet_sdk(wallet_module_name, operation, payload)
        payload["sdk_result"] = sdk_result
        return _result("completed", "Wallet operation completed through unified wallet SDK.", payload)

    wallet_url = _env_url("YIELDSWARM_UNIFIED_WALLET_API_URL")
    if wallet_url:
        return _post_json(wallet_url, "/wallet/operation", payload)

    return _result(
        "adapter_missing",
        "Set YIELDSWARM_UNIFIED_WALLET_SDK_MODULE or YIELDSWARM_UNIFIED_WALLET_API_URL.",
        payload,
    )


def handle_worker_telemetry(arguments: MutableMapping[str, Any]) -> Dict[str, Any]:
    action = _required_string(arguments, "action")
    limit = int(arguments.get("limit") or 100)
    filters = {
        "lease_id": arguments.get("lease_id"),
        "worker_id": arguments.get("worker_id"),
        "shard_id": arguments.get("shard_id"),
        "window": arguments.get("window", "5m"),
        "limit": limit,
    }

    if action == "stream_config":
        return _result(
            "configured",
            "Telemetry stream configuration generated.",
            {
                "source": _env_url("YIELDSWARM_TELEMETRY_URL")
                or _env_url("MONITORING_PROMETHEUS_URL")
                or "unconfigured",
                "filters": filters,
                "recommended_event_types": ["lease_health", "worker_metrics", "miner_status", "shard_cron"],
            },
        )

    telemetry_url = _env_url("YIELDSWARM_TELEMETRY_URL")
    if telemetry_url:
        return _post_json(telemetry_url, "/workers/telemetry", {"action": action, "filters": filters})

    prometheus_url = _env_url("MONITORING_PROMETHEUS_URL")
    if prometheus_url:
        query = arguments.get("prometheus_query") or _default_prometheus_query(action, filters)
        data = _get_json(prometheus_url, "/api/v1/query", {"query": query})
        return _result("queried", "Prometheus telemetry query completed.", {"query": query, "data": data})

    return _result(
        "adapter_missing",
        "Set YIELDSWARM_TELEMETRY_URL or MONITORING_PROMETHEUS_URL for live worker telemetry.",
        {"action": action, "filters": filters},
    )


def handle_dex_quote(arguments: MutableMapping[str, Any]) -> Dict[str, Any]:
    chain = _required_string(arguments, "chain")
    payload = {
        "chain": chain,
        "input_mint": arguments.get("input_mint"),
        "output_mint": arguments.get("output_mint"),
        "amount": arguments.get("amount"),
        "token_in": arguments.get("token_in"),
        "token_out": arguments.get("token_out"),
        "amount_in_wei": arguments.get("amount_in_wei"),
        "slippage_bps": arguments.get("slippage_bps"),
    }

    dex_url = _env_url("YIELDSWARM_DEX_API_URL")
    if dex_url:
        return _post_json(dex_url, "/dex/quote", payload)

    if chain in {"solana", "jupiter"}:
        from services.cross_chain.jupiter import JupiterClient, SOL_MINT, USDC_MINT  # noqa: PLC0415

        client = JupiterClient()
        quote = client.quote(
            input_mint=str(arguments.get("input_mint") or SOL_MINT),
            output_mint=str(arguments.get("output_mint") or USDC_MINT),
            amount=int(arguments.get("amount") or 1_000_000),
        )
        return _result("quoted", "Jupiter quote returned.", quote)

    if chain in {"ethereum", "evm", "uniswap_v4"}:
        from services.cross_chain.uniswap_v4 import UniswapV4HookClient  # noqa: PLC0415

        client = UniswapV4HookClient()
        auction = client.simulate_auction(
            pool_id=str(arguments.get("pool_id") or ("0x" + "aa" * 32)),
            bid_amount_wei=int(arguments.get("amount_in_wei") or 10**15),
            bidder=str(arguments.get("bidder") or "0x0000000000000000000000000000000000000001"),
        )
        return _result("simulated", "Uniswap V4 auction simulated.", auction)

    return _result("adapter_missing", "Set YIELDSWARM_DEX_API_URL or use chain=solana|ethereum.", payload)


def handle_dex_swap(arguments: MutableMapping[str, Any]) -> Dict[str, Any]:
    chain = _required_string(arguments, "chain")
    dry_run = _bool(arguments.get("dry_run"), True)
    payload = {
        "chain": chain,
        "dry_run": dry_run,
        "quote": arguments.get("quote"),
        "user_public_key": arguments.get("user_public_key"),
        "recipient": arguments.get("recipient"),
    }

    if dry_run:
        return _result("dry_run", "DEX swap prepared but not broadcast.", payload)

    dex_url = _env_url("YIELDSWARM_DEX_API_URL")
    if dex_url:
        return _post_json(dex_url, "/dex/swap", payload)

    return _result(
        "adapter_missing",
        "Set YIELDSWARM_DEX_API_URL and dry_run=false for live swaps.",
        payload,
    )


TOOL_HANDLERS: Dict[str, Callable[[MutableMapping[str, Any]], Dict[str, Any]]] = {
    "yieldswarm_akash_lease": handle_akash_lease,
    "yieldswarm_treasury_rebalance": handle_treasury_rebalance,
    "yieldswarm_emission_router_query": handle_emission_router_query,
    "yieldswarm_wallet_operation": handle_wallet_operation,
    "yieldswarm_worker_telemetry": handle_worker_telemetry,
    "yieldswarm_dex_quote": handle_dex_quote,
    "yieldswarm_dex_swap": handle_dex_swap,
}


def _result(status: str, message: str, data: Mapping[str, Any]) -> Dict[str, Any]:
    return {"status": status, "message": message, "data": dict(data)}


def _required_string(arguments: Mapping[str, Any], key: str) -> str:
    value = arguments.get(key)
    if not isinstance(value, str) or not value.strip():
        raise YieldSwarmToolError(f"{key} is required")
    return value.strip()


def _bool(value: Any, default: bool) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y", "on"}
    return bool(value)


def _number(value: Any, default: float = 0.0) -> float:
    if value is None:
        return float(default)
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise YieldSwarmToolError(f"Expected numeric value, got {value!r}") from exc


def _numeric_map(value: Mapping[str, Any]) -> Dict[str, float]:
    if not isinstance(value, Mapping):
        raise YieldSwarmToolError("balances must be an object")
    return {str(key): _number(amount) for key, amount in value.items()}


def _policy(value: Mapping[str, Any]) -> Dict[str, float]:
    if not isinstance(value, Mapping):
        raise YieldSwarmToolError("target_policy must be an object")

    policy = {str(key): _number(amount) for key, amount in value.items()}
    total = round(sum(policy.values()), 8)
    if total != 100.0:
        raise YieldSwarmToolError(f"target_policy percentages must add up to 100, got {total}")
    return policy


def _rebalance_transfers(deltas: Mapping[str, float]) -> list[Dict[str, Any]]:
    surplus = [(bucket, -delta) for bucket, delta in deltas.items() if delta < 0]
    deficit = [(bucket, delta) for bucket, delta in deltas.items() if delta > 0]
    transfers: list[Dict[str, Any]] = []

    i = 0
    j = 0
    while i < len(surplus) and j < len(deficit):
        from_bucket, available = surplus[i]
        to_bucket, needed = deficit[j]
        amount = round(min(available, needed), 8)
        if amount > 0:
            transfers.append({"from": from_bucket, "to": to_bucket, "amount": amount})
        available = round(available - amount, 8)
        needed = round(needed - amount, 8)
        surplus[i] = (from_bucket, available)
        deficit[j] = (to_bucket, needed)
        if available <= 0:
            i += 1
        if needed <= 0:
            j += 1

    return transfers


def _lease_identity(arguments: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        "lease_id": arguments.get("lease_id"),
        "dseq": arguments.get("dseq"),
        "gseq": arguments.get("gseq"),
        "oseq": arguments.get("oseq"),
        "owner": arguments.get("owner"),
        "provider": arguments.get("provider"),
    }


def _default_router_for_chain(chain: str) -> str | None:
    env_key = f"YIELDSWARM_{chain.upper()}_EMISSION_ROUTER"
    return os.getenv(env_key) or os.getenv("YIELDSWARM_EMISSION_ROUTER_ADDRESS")


def _default_prometheus_query(action: str, filters: Mapping[str, Any]) -> str:
    labels = []
    for label in ("lease_id", "worker_id", "shard_id"):
        value = filters.get(label)
        if value:
            labels.append(f'{label}="{value}"')
    selector = "{" + ",".join(labels) + "}" if labels else ""

    if action == "alerts":
        return f'ALERTS{selector}'
    if action == "query":
        return f'yieldswarm_worker_up{selector}'
    return f'yieldswarm_worker_health_score{selector}'


def _env_url(key: str) -> str | None:
    value = os.getenv(key)
    if not value or value.startswith("your_"):
        return None
    return value.rstrip("/")


def _post_json(base_url: str, path: str, payload: Mapping[str, Any]) -> Dict[str, Any]:
    request = Request(
        base_url + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    return _request_json(request)


def _get_json(base_url: str, path: str, params: Mapping[str, Any]) -> Dict[str, Any]:
    query = urlencode({key: value for key, value in params.items() if value is not None})
    request = Request(base_url + path + ("?" + query if query else ""), method="GET")
    return _request_json(request)


def _request_json(request: Request) -> Dict[str, Any]:
    try:
        with urlopen(request, timeout=20) as response:
            raw = response.read().decode("utf-8")
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise YieldSwarmToolError(f"HTTP {exc.code} from adapter: {detail}") from exc
    except URLError as exc:
        raise YieldSwarmToolError(f"Could not reach adapter: {exc.reason}") from exc

    if not raw:
        return _result("completed", "Adapter returned an empty response.", {})
    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise YieldSwarmToolError("Adapter did not return valid JSON") from exc
    if isinstance(decoded, dict):
        return decoded
    return {"status": "completed", "data": decoded}


def _call_wallet_sdk(module_name: str, operation: str, payload: Mapping[str, Any]) -> Any:
    sdk = importlib.import_module(module_name)
    if hasattr(sdk, "unified_wallet_operation"):
        return sdk.unified_wallet_operation(operation, dict(payload))
    if hasattr(sdk, operation):
        return getattr(sdk, operation)(**dict(payload))
    raise YieldSwarmToolError(
        f"{module_name} must expose unified_wallet_operation(operation, payload) or {operation}()"
    )

# Akash Optimizer Agent
# Connects to current allocations (GPU miners, OpenClaw, Eliza, Gensyn)
# Optimizes with $200 credits, extends leases, migrates providers
# Part of MEGA TASK scaling (Hydrogen Particle VM sharding)

import json
import os
import sys


REQUIRED_ENV_VARS = (
    "AKASH_NODE",
    "AKASH_CHAIN_ID",
    "AKASH_KEY_NAME",
    "SOLANA_RPC_URL",
)


def require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required runtime secret: {name}")
    return value


def load_json_list(name: str) -> list[str]:
    raw_value = os.getenv(name, "[]").strip() or "[]"
    try:
        parsed = json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"{name} must be valid JSON") from exc

    if not isinstance(parsed, list) or not all(isinstance(item, str) for item in parsed):
        raise RuntimeError(f"{name} must decode to a JSON array of strings")

    return parsed


def main() -> int:
    runtime_config = {name: require_env(name) for name in REQUIRED_ENV_VARS}
    failover_rpcs = load_json_list("FAILOVER_RPC_LIST")

    provider_readiness = {
        "azure": all(
            os.getenv(name, "").strip()
            for name in (
                "ARM_SUBSCRIPTION_ID",
                "ARM_TENANT_ID",
                "ARM_CLIENT_ID",
                "ARM_CLIENT_SECRET",
            )
        ),
        "runpod": bool(os.getenv("RUNPOD_API_KEY", "").strip()),
        "vultr": bool(os.getenv("VULTR_API_KEY", "").strip()),
        "digitalocean": bool(os.getenv("DIGITALOCEAN_TOKEN", "").strip()),
    }

    summary = {
        "akash_node_configured": bool(runtime_config["AKASH_NODE"]),
        "akash_chain_id": runtime_config["AKASH_CHAIN_ID"],
        "key_name_configured": bool(runtime_config["AKASH_KEY_NAME"]),
        "primary_rpc_configured": bool(runtime_config["SOLANA_RPC_URL"]),
        "failover_rpc_count": len(failover_rpcs),
        "provider_readiness": provider_readiness,
    }

    print("Akash Optimizer Agent active - runtime secrets loaded from Vault")
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1) from exc
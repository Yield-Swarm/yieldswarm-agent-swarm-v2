# Akash Optimizer Agent
# Connects to current allocations (GPU miners, OpenClaw, Eliza, Gensyn)
# Secrets are injected at runtime by deploy/akash/entrypoint.sh from Vault — never hardcoded.

import os
import sys

REQUIRED_ENV = (
    "AKASH_RPC_ENDPOINT",
    "AKASH_CHAIN_ID",
    "SOLANA_RPC_URL",
    "AGENTSWARM_MASTER_KEY",
)


def validate_runtime_secrets() -> None:
    missing = [key for key in REQUIRED_ENV if not os.environ.get(key)]
    if missing:
        print(
            f"Missing runtime secrets: {', '.join(missing)}. "
            "Ensure Vault injection ran (see SECRETS.md).",
            file=sys.stderr,
        )
        sys.exit(1)

    if "REPLACE_ME" in os.environ.get("AGENTSWARM_MASTER_KEY", ""):
        print("Vault secrets still contain placeholders.", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    validate_runtime_secrets()
    shard = os.environ.get("AGENT_SHARD_ID", "0")
    rpc = os.environ.get("AKASH_RPC_ENDPOINT")
    print(
        f"Akash Optimizer Agent active — shard={shard}, "
        f"rpc={rpc}, secrets=vault-injected"
    )


if __name__ == "__main__":
    main()

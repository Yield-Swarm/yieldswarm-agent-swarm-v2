"""Akash Optimizer Agent — secrets loaded at runtime via Vault entrypoint."""

from __future__ import annotations

import os

from lib.secrets import get_rpc_config, validate_or_exit

REQUIRED_SECRETS = [
    "AGENTSWARM_MASTER_KEY",
    "SOLANA_RPC_URL",
    "WALLET_MNEMONIC",
]


def main() -> None:
    validate_or_exit(REQUIRED_SECRETS)

    rpc = get_rpc_config()
    shard_id = os.environ.get("AGENT_SHARD_ID", "0")
    chain_id = os.environ.get("CHAIN_ID", "akashnet-2")
    akash_node = os.environ.get("NODE", "https://rpc.akash.forbole.com:443")

    # Secrets are present — safe to proceed without logging values
    print(
        f"Akash Optimizer Agent active — "
        f"shard={shard_id} chain={chain_id} "
        f"rpc_endpoints={1 + len(rpc['failover'])}"
    )
    print(f"Connecting to Akash node: {akash_node}")
    print("Monitoring DSEQ, optimizing leases for profit.")


if __name__ == "__main__":
    main()

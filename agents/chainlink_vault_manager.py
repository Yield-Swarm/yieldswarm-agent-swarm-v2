"""Chainlink Vault Manager Agent — treasury operations (not HashiCorp Vault)."""

import os

from lib.secrets import init_secrets


def run() -> None:
    init_secrets()
    rpc = os.environ.get("SOLANA_RPC_URL", "")
    print(f"Chainlink Vault Manager active — rpc_configured={bool(rpc)}")


if __name__ == "__main__":
    run()

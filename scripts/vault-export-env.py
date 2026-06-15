#!/usr/bin/env python3
"""Export Vault KV secrets as shell KEY=VALUE lines for container entrypoints."""

from __future__ import annotations

import os
import sys

# Map CLI arg → KV path suffix under yieldswarm/
PATHS = {
    "bittensor": "runtime/bittensor",
    "akash": "runtime/akash",
    "odysseus": "runtime/odysseus",
    "kairo": "runtime/kairo",
    "payments": "runtime/payments",
}

# Vault key → environment variable
ENV_MAP = {
    "wallet_name": "BT_WALLET_NAME",
    "hotkey_name": "BT_HOTKEY_NAME",
    "wallet_json": "BITTENSOR_WALLET_JSON",
    "netuid": "BT_NETUID",
    "network": "BT_NETWORK",
    "ollama_model": "OLLAMA_MODEL",
    "mnemonic": "AKASH_WALLET_MNEMONIC",
    "key_name": "AKASH_KEY_NAME",
}


def main() -> int:
    profile = sys.argv[1] if len(sys.argv) > 1 else "bittensor"
    path = PATHS.get(profile, profile)

    if not os.getenv("VAULT_ADDR"):
        return 1

    sys.path.insert(0, "/app")
    try:
        from lib.secrets import _read_kv_path, KV_MOUNT_DEFAULT
    except ImportError:
        return 1

    data = _read_kv_path(KV_MOUNT_DEFAULT, path)
    for key, value in data.items():
        env_key = ENV_MAP.get(key, key.upper())
        # shell-safe single-quoted export
        escaped = str(value).replace("'", "'\"'\"'")
        print(f"export {env_key}='{escaped}'")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Export Vault KV secrets as shell export KEY=VALUE lines for container entrypoints."""

from __future__ import annotations

import os
import sys

# CLI profile → default KV path suffix under yieldswarm/
PATHS: dict[str, str] = {
    "bittensor": "runtime/bittensor",
    "backend": "runtime/backend",
    "akash": "runtime/akash",
    "odysseus": "runtime/odysseus",
    "kairo": "runtime/kairo",
    "payments": "runtime/payments",
    "mining": "mining/wallets",
}

# Vault key → environment variable (shared across paths; last write wins)
ENV_MAP: dict[str, str] = {
    # Bittensor
    "wallet_name": "BT_WALLET_NAME",
    "hotkey_name": "BT_HOTKEY_NAME",
    "wallet_json": "BITTENSOR_WALLET_JSON",
    "netuid": "BT_NETUID",
    "network": "BT_NETWORK",
    "ollama_model": "OLLAMA_MODEL",
    # Akash
    "owner_address": "AKASH_OWNER_ADDRESS",
    "mnemonic": "AKASH_WALLET_MNEMONIC",
    "key_name": "AKASH_KEY_NAME",
    # RPC (solana / ethereum)
    "url": "SOLANA_RPC_URL",
    "helius_api_key": "HELIUS_API_KEY",
    "alchemy_api_key": "ALCHEMY_API_KEY",
    "infura_project_id": "INFURA_PROJECT_ID",
    "staking_key": "NG64_BITTENSOR_NODE_STAKING_KEY",
    # Backend / on-chain telemetry
    "emission_router_address": "EMISSION_ROUTER_ADDRESS",
    "treasury_address": "TREASURY_ADDRESS",
    "apn_mint": "APN_MINT_ADDRESS",
    "split_core_bps": "SPLIT_CORE_BPS",
    "split_growth_bps": "SPLIT_GROWTH_BPS",
    "split_insurance_bps": "SPLIT_INSURANCE_BPS",
    "split_ops_bps": "SPLIT_OPS_BPS",
    # Odysseus
    "api_key": "ODYSSEUS_API_KEY",
    "model_host": "ODYSSEUS_MODEL_HOST",
    "model_api_key": "ODYSSEUS_MODEL_API_KEY",
    "router_api_key": "YIELDSWARM_ROUTER_API_KEY",
    "openrouter_api_key": "OPENROUTER_API_KEY",
    "fireworks_api_key": "FIREWORKS_API_KEY",
    # Mining wallets
    "tao": "MINING_ROOT_TAO",
    "monero": "MONERO_WALLET_ADDRESS",
    "etc": "MINING_ROOT_BASE_ETC",
    "grass_nodes": "GRASS_NODE_KEYS",
    "helium_hotspots": "DEPIN_HELIUM_HOTSPOT_KEYS",
    "grass_lineups": "GRASS_LINEUPS",
    "solana_treasury": "NEXUS_TREASURY_SOLANA",
}


def _paths_for_profile(profile: str) -> list[str]:
    explicit = os.getenv("VAULT_SECRET_PATHS", "").strip()
    if explicit:
        return [p.strip() for p in explicit.split(",") if p.strip()]
    return [PATHS.get(profile, profile)]


def main() -> int:
    profile = sys.argv[1] if len(sys.argv) > 1 else "bittensor"

    if not os.getenv("VAULT_ADDR"):
        return 1

    sys.path.insert(0, "/app")
    try:
        from lib.secrets import _read_kv_path, KV_MOUNT_DEFAULT
    except ImportError:
        return 1

    mount = os.getenv("VAULT_KV_MOUNT", KV_MOUNT_DEFAULT)
    merged: dict[str, str] = {}

    for path in _paths_for_profile(profile):
        data = _read_kv_path(mount, path)
        merged.update({str(k): str(v) for k, v in data.items() if v is not None})

    for key, value in merged.items():
        env_key = ENV_MAP.get(key, key.upper())
        escaped = str(value).replace("'", "'\"'\"'")
        print(f"export {env_key}='{escaped}'")
    return 0 if merged else 1


if __name__ == "__main__":
    raise SystemExit(main())

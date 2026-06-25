#!/usr/bin/env python3
"""Normalize .env.example → example.env for HashiCloud / Vault seeding."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / ".env.example"
OUT_EXAMPLE = ROOT / "example.env"

HEADER = """# YieldSwarm AgentSwarm OS — example.env (HashiCloud / HCP Vault upload template)
# =============================================================================
# 1. Copy:  cp example.env .env
# 2. Fill every your_* / change_me / empty secret in .env (never commit .env)
# 3. Seed:  set -a && source .env && set +a && ./vault/scripts/seed-secrets.sh
# Docs:    docs/HASHICLOUD_ENV_UPLOAD.md · docs/VAULT_SECRET_STRUCTURE.md
# Catalog: docs/ENV_VARS.md · seed script: vault/scripts/seed-secrets.sh
# =============================================================================
# Placeholders only — rotate any secret ever pasted in chat or Polsia logs.
"""

VAULT_AKASH_INSERT = """
# Operator token (seed host only — never commit, never put in SDL)
VAULT_TOKEN=
KV_MOUNT=yieldswarm
VAULT_KV_MOUNT=yieldswarm
VAULT_ROLE_ID=
VAULT_SECRET_ID=
VAULT_WRAPPED_SECRET_ID=
VAULT_SECRET_ID_WRAP_TOKEN=
VAULT_AKASH_ROLE=akash-runtime
VAULT_WRAP_TTL=600s
VAULT_INJECT_RUNTIME_SECRETS=auto
USE_VAULT_AKASH=true
VAULT_LOAD_AKASH=false
VAULT_AKASH_SECRET_PATH=yieldswarm/data/runtime/akash

# ---- Akash deploy (see deploy/akash.env.example) ----
AKASH_KEY_NAME=yieldswarm
AKASH_KEYRING_BACKEND=os
AKASH_OWNER_ADDRESS=
AKASH_WALLET_MNEMONIC=
AKASH_ACCOUNT_ADDRESS=
AKASH_NODE=https://rpc.akashnet.net:443
AKASH_CHAIN_ID=akashnet-2
AKASH_GAS=auto
AKASH_GAS_ADJUSTMENT=1.4
AKASH_GAS_PRICES=0.025uakt
AKASH_DEPOSIT=5000000uakt
AKASH_AUTH_MODE=jwt
AKASH_SDL=deploy/deploy-swarm-monolith.yaml
AKASH_GPU_MODEL=rtx3090
AKASH_MAX_BID_PRICE=700000
AKASH_BID_WAIT_SECONDS=180
AKASH_BID_POLL_INTERVAL=10
AKASH_PROVIDER=
AKASH_CONSOLE_API=https://console-api.akash.network/v1
"""

PUBLIC_ADDRESS_KEYS = {
    "NEXUS_TREASURY_SOLANA",
    "MINING_ROOT_TAO",
    "MINING_ROOT_BASE_ETC",
    "MINING_ROOT_ZEC",
    "MINING_ROOT_PRL",
    "MINING_ROOT_BASE_HYPE",
    "MINING_ROOT_BASE_CBETH",
    "MINING_ROOT_BASE_BTC",
    "IOTEX_TREASURY",
    "IOTEX_BTC_BRIDGE",
}

REDACTED_PLACEHOLDER = {
    "AGENTSWARM_MASTER_KEY": "your_agentswarm_master_key_here",
    "WALLET_ENCRYPTION_KEY": "your_wallet_encryption_key_here",
    "TEE_SIGNING_KEY": "your_tee_signing_key_here",
    "DATABASE_ENCRYPTION_KEY": "your_database_encryption_key_here",
    "SOLANA_RPC_URL": "https://mainnet.helius-rpc.com/?api-key=your_helius_api_key",
    "HELIUS_API_KEY": "your_helius_api_key_here",
    "BIRDEYE_API_KEY": "your_birdeye_api_key_here",
    "JUPITER_API_KEY": "your_jupiter_api_key_here",
    "RAYDIUM_API_KEY": "your_raydium_api_key_here",
    "TAO_SUBNET_KEY": "your_tao_subnet_key_here",
    "PUMP_FUN_DEPLOY_KEY": "your_pump_fun_deploy_key_here",
    "HELIX_CHAIN_BRIDGE_KEY": "your_helix_chain_bridge_key_here",
    "ZEC_SHIELDED_KEY": "your_zec_shielded_key_here",
    "ERC4337_BUNDLER_KEY": "your_erc4337_bundler_key_here",
    "APN_MINT_ADDRESS": "your_apn_mint_address_here",
    "PUMP_FUN_COIN_ID": "your_pump_fun_coin_id_here",
    "RAYDIUM_POOL_ID": "your_raydium_pool_id_here",
    "LP_TOKEN_ADDRESS": "your_lp_token_address_here",
    "GPU_CLUSTER_KEYS": "[]",
    "GRASS_NODE_KEYS": "[]",
    "SMARTTHINGS_BRIDGE_TOKEN": "your_smartthings_bridge_token_here",
    "COLORADO_POWER_PERMIT_ID": "your_colorado_power_permit_id_here",
    "LINEAR_API_KEY": "your_linear_api_key_here",
    "GITHUB_TOKEN": "your_github_token_here",
    "S_AND_P_API_KEY": "your_s_and_p_api_key_here",
    "FSD_DATA_FEED_KEY": "your_fsd_data_feed_key_here",
    "TELEGRAM_BOT_TOKEN": "your_telegram_bot_token_here",
    "META_ADS_TOKEN": "your_meta_ads_token_here",
    "IPFS_GATEWAY": "https://ipfs.io/ipfs/",
    "FILECOIN_STORAGE_KEY": "your_filecoin_storage_key_here",
    "MONITORING_PROMETHEUS_URL": "http://127.0.0.1:9090",
    "ERROR_WEBHOOK": "your_error_webhook_url_here",
    "ADMIN_ACCOUNT_SEGMENT": "your_admin_account_segment_here",
    "QUARANTINED_LLM_ARENA_KEY": "your_quarantined_llm_arena_key_here",
    "ZKML_VERIFIER_KEY": "your_zkml_verifier_key_here",
    "DEXSCREENER_API": "your_dexscreener_api_key_here",
    "SOLSCAN_API_KEY": "your_solscan_api_key_here",
    "EMAIL_SMTP_CONFIG": "{}",
    "FAILOVER_RPC_LIST": "[]",
    "NG64_BITTENSOR_NODE_STAKING_KEY": "your_bittensor_staking_key_here",
    "BITTENSOR_TRAINING_CONFIG": '{"epochs": 10}',
    "NEXT_PUBLIC_SOLANA_RPC_URL": "https://api.mainnet-beta.solana.com",
}


def placeholder_for_key(key: str) -> str:
    if key in REDACTED_PLACEHOLDER:
        return REDACTED_PLACEHOLDER[key]
    if key in PUBLIC_ADDRESS_KEYS:
        return f"your_{key.lower()}_here"
    lower = key.lower()
    if lower.endswith("_private_key") or lower.endswith("_secret_key"):
        return f"your_{lower}_here"
    if "MNEMONIC" in key:
        return "your_wallet_mnemonic_phrase_here"
    if key.endswith("_KEY") or key.endswith("_TOKEN") or key.endswith("_SECRET"):
        return f"your_{lower}_here"
    if key.endswith("_ADDRESS"):
        return f"your_{lower}_here"
    return "your_value_here"


def parse_line(line: str) -> tuple[str | None, str | None, str]:
    stripped = line.rstrip("\n")
    if not stripped or stripped.lstrip().startswith("#"):
        return None, None, stripped
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", stripped)
    if not m:
        return None, None, stripped
    return m.group(1), m.group(2), stripped


def normalize_value(key: str, value: str, *, for_example: bool) -> str:
    if value == "[REDACTED]":
        return placeholder_for_key(key)
    if for_example and key in PUBLIC_ADDRESS_KEYS and value and not value.startswith("your_"):
        return placeholder_for_key(key)
    if for_example and key == "WISE_BUSINESS_EMAIL" and "@" in value:
        return "your_wise_business_email@example.com"
    if for_example and key == "RTX5090_ENDPOINT" and "akash.pub" in value:
        return "http://your-rtx5090-lease.example.com:11434"
    return value


def source_has_vault_akash_block(text: str) -> bool:
    return any(parse_line(raw)[0] == "AKASH_WALLET_MNEMONIC" for raw in text.splitlines())


def dedupe_and_build(text: str, *, for_example: bool) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    inserted_vault_akash = source_has_vault_akash_block(text)

    for raw_line in text.splitlines():
        key, value, line = parse_line(raw_line)

        if key is None:
            if raw_line.startswith("# YieldSwarm AgentSwarm OS"):
                continue
            if raw_line.startswith("# For 10,080 AI Agents"):
                continue
            if raw_line.startswith("# Layered template"):
                continue
            if raw_line.startswith("# Deploy order:") and "DEPLOYMENT_PRIORITY" in raw_line:
                continue
            if raw_line.startswith("# Vault injection:"):
                continue
            if raw_line.startswith("# Kimiclaw"):
                continue
            if raw_line.startswith("# Post-Polsia"):
                continue
            if raw_line.startswith("# Fill in values"):
                continue
            if raw_line.startswith("# Use for Vercel"):
                continue
            if raw_line.startswith("# LAYERED TEMPLATE"):
                continue
            if raw_line.startswith("#   cp deploy/env"):
                continue
            if raw_line.startswith("# Vault migration:") and "VAULT_ENV" in raw_line:
                continue
            if raw_line.strip() == "# Operator token (seed host only — never commit, never put in SDL)":
                continue
            if raw_line.strip() == "# ---- Akash deploy (see deploy/akash.env.example) ----":
                continue
            out.append(line)
            continue

        if key in seen:
            continue
        seen.add(key)

        norm = normalize_value(key, value or "", for_example=for_example)
        out.append(f"{key}={norm}")

        if not inserted_vault_akash and key == "ODYSSEUS_DEPLOY_VAULT_PATH":
            out.append(VAULT_AKASH_INSERT.rstrip("\n"))
            inserted_vault_akash = True

    if not inserted_vault_akash:
        out.append(VAULT_AKASH_INSERT.rstrip("\n"))

    return out


def main() -> int:
    if not SRC.exists():
        print(f"missing {SRC}", file=sys.stderr)
        return 1

    src_text = SRC.read_text(encoding="utf-8")
    example_lines = dedupe_and_build(src_text, for_example=True)
    OUT_EXAMPLE.write_text(HEADER + "\n".join(example_lines) + "\n", encoding="utf-8")

    example_body = dedupe_and_build(src_text, for_example=False)
    fixed: list[str] = []
    for line in example_body:
        key, value, _ = parse_line(line)
        if key and value == "[REDACTED]":
            fixed.append(f"{key}={placeholder_for_key(key)}")
        else:
            fixed.append(line)

    env_example_header = """# YieldSwarm AgentSwarm OS — .env.example
# Canonical template (committed). For HashiCloud upload use example.env (same keys).
#   cp example.env .env   OR   cp .env.example .env
# Docs: docs/HASHICLOUD_ENV_UPLOAD.md · docs/ENV_VARS.md
# Never commit real secrets.
"""
    SRC.write_text(env_example_header + "\n".join(fixed) + "\n", encoding="utf-8")

    local_env = ROOT / ".env"
    local_env.write_text(OUT_EXAMPLE.read_text(encoding="utf-8"), encoding="utf-8")

    print(f"wrote {OUT_EXAMPLE} ({len(example_lines)} lines)")
    print(f"updated {SRC}")
    print(f"wrote {local_env} (gitignored)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

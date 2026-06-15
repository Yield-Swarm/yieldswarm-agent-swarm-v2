#!/usr/bin/env bash
# =============================================================================
# 30-seed-secrets.sh
# -----------------------------------------------------------------------------
# Create the empty KV-v2 paths that the rest of the platform expects to exist.
# This script DOES NOT seed real credential values; it only stamps placeholder
# version 1 entries so:
#
#   1. Vault policy paths are valid (KV-v2 needs `data/` to exist).
#   2. Terraform `vault_kv_secret_v2` data sources don't fail-fast on a fresh
#      cluster.
#   3. Operators can run `vault kv patch yieldswarm/infra/azure key=value`
#      to fill in real values out-of-band via the CLI / Web UI / OIDC.
#
# To inject real values from a CI vault (e.g. a one-time-use offline file),
# use 31-seed-secrets-from-file.sh (NOT checked in; see SECRETS.md).
# =============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

log() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }

put_if_missing() {
  local path="$1"; shift
  if vault kv get -format=json "$path" >/dev/null 2>&1; then
    log "exists, skipping: $path"
    return 0
  fi
  log "seeding placeholder: $path"
  vault kv put "$path" "$@" >/dev/null
}

# --- Infra provider credentials (read by Terraform) -------------------------
put_if_missing yieldswarm/infra/azure \
  subscription_id="REPLACE_ME" \
  tenant_id="REPLACE_ME" \
  client_id="REPLACE_ME" \
  client_secret="REPLACE_ME" \
  resource_group="yieldswarm-prod" \
  location="eastus2"

put_if_missing yieldswarm/infra/runpod \
  api_key="REPLACE_ME" \
  org_id="REPLACE_ME" \
  default_pod_type="NVIDIA_RTX_4090"

put_if_missing yieldswarm/infra/vultr \
  api_key="REPLACE_ME" \
  default_region="ewr" \
  default_plan="vhf-2c-4gb"

put_if_missing yieldswarm/infra/digitalocean \
  api_token="REPLACE_ME" \
  spaces_access_key="REPLACE_ME" \
  spaces_secret_key="REPLACE_ME" \
  default_region="nyc3"

# --- RPC endpoints (one path per chain) -------------------------------------
put_if_missing yieldswarm/rpc/solana \
  primary="https://api.mainnet-beta.solana.com" \
  helius="https://mainnet.helius-rpc.com/?api-key=REPLACE_ME" \
  failover="https://solana-api.projectserum.com" \
  api_key="REPLACE_ME"

put_if_missing yieldswarm/rpc/ton \
  primary="https://toncenter.com/api/v2/jsonRPC" \
  api_key="REPLACE_ME"

put_if_missing yieldswarm/rpc/tao \
  primary="wss://entrypoint-finney.opentensor.ai:443" \
  subnet_key="REPLACE_ME"

put_if_missing yieldswarm/rpc/helix \
  primary="https://rpc.helixchain.example" \
  bridge_key="REPLACE_ME"

put_if_missing yieldswarm/rpc/zec \
  primary="https://zec.example/rpc" \
  shielded_key="REPLACE_ME"

put_if_missing yieldswarm/rpc/erc4337 \
  primary="https://bundler.example/rpc" \
  bundler_key="REPLACE_ME"

# --- Runtime application secrets (read by Akash workloads) ------------------
put_if_missing yieldswarm/runtime/app \
  AGENTSWARM_MASTER_KEY="REPLACE_ME" \
  KIMICLAW_CONSENSUS_KEY="REPLACE_ME" \
  GROK_API_KEY="REPLACE_ME" \
  OPENAI_API_KEY="REPLACE_ME" \
  GEMINI_API_KEY="REPLACE_ME" \
  ANTHROPIC_API_KEY="REPLACE_ME" \
  TEE_SIGNING_KEY="REPLACE_ME" \
  DATABASE_ENCRYPTION_KEY="REPLACE_ME"

put_if_missing yieldswarm/runtime/wallet \
  WALLET_ENCRYPTION_KEY="REPLACE_ME" \
  PUMP_FUN_DEPLOY_KEY="REPLACE_ME" \
  RAYDIUM_POOL_ID="REPLACE_ME" \
  LP_TOKEN_ADDRESS="REPLACE_ME"

put_if_missing yieldswarm/runtime/depin \
  DEPIN_HELIUM_HOTSPOT_KEYS='["REPLACE_ME"]' \
  GPU_CLUSTER_KEYS='["REPLACE_ME"]' \
  GRASS_NODE_KEYS='["REPLACE_ME"]' \
  SMARTTHINGS_BRIDGE_TOKEN="REPLACE_ME" \
  UTILITY_API_KEY="REPLACE_ME"

put_if_missing yieldswarm/runtime/social \
  TELEGRAM_BOT_TOKEN="REPLACE_ME" \
  X_API_KEYS='["REPLACE_ME"]' \
  META_ADS_TOKEN="REPLACE_ME" \
  NOTION_API_KEY="REPLACE_ME" \
  LINEAR_API_KEY="REPLACE_ME" \
  VERCEL_API_TOKEN="REPLACE_ME" \
  GITHUB_TOKEN="REPLACE_ME" \
  UD_API_KEY="REPLACE_ME"

# --- Build-time credentials (read by CI) ------------------------------------
put_if_missing yieldswarm/build/registry \
  ghcr_user="REPLACE_ME" \
  ghcr_token="REPLACE_ME" \
  docker_hub_user="REPLACE_ME" \
  docker_hub_token="REPLACE_ME"

put_if_missing yieldswarm/build/vercel \
  api_token="REPLACE_ME" \
  team_id="REPLACE_ME" \
  project_id="REPLACE_ME"

log "Seed complete. Populate real values with:"
log "  vault kv patch yieldswarm/<path> key=value"

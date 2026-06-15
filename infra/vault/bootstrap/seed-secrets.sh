#!/usr/bin/env bash
# =============================================================================
# YieldSwarm — seed secrets into Vault KV v2
# -----------------------------------------------------------------------------
# Reads secret values from the environment ONLY and writes them to the
# YieldSwarm KV tree. No secret value is ever hardcoded in this file.
#
# Run this from a trusted, ephemeral admin shell (ideally air-gapped / TEE).
# Export the variables you want to populate, then run the script. Any group
# whose required variables are all empty is skipped, so you can seed
# incrementally (e.g. only RPC today, cloud creds later).
#
# Requires: vault CLI, VAULT_ADDR, VAULT_TOKEN (a token with secrets-admin or
# root). The KV layout written here matches the policies and the Terraform /
# Akash consumers.
# =============================================================================
set -euo pipefail

KV_MOUNT="${KV_MOUNT:-kv}"

log()  { printf '\033[1;34m[seed]\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m[seed:skip]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[seed:error]\033[0m %s\n' "$*" >&2; exit 1; }

command -v vault >/dev/null 2>&1 || die "vault CLI not found on PATH"
: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

# put_secret <path> <k=v> [<k=v> ...]
# Skips the whole group if every value resolves to empty.
put_secret() {
  local path="$1"; shift
  local has_value=0 kv
  for kv in "$@"; do
    [ -n "${kv#*=}" ] && has_value=1
  done
  if [ "$has_value" -eq 0 ]; then
    skip "kv/${path} — no values provided, skipping"
    return 0
  fi
  log "Writing kv/${path}"
  vault kv put -mount="${KV_MOUNT}" "${path}" "$@" >/dev/null
}

# --- Azure (azurerm provider) ----------------------------------------------
put_secret "yieldswarm/cloud/azure" \
  subscription_id="${AZURE_SUBSCRIPTION_ID:-}" \
  tenant_id="${AZURE_TENANT_ID:-}" \
  client_id="${AZURE_CLIENT_ID:-}" \
  client_secret="${AZURE_CLIENT_SECRET:-}"

# --- RunPod (decentralized-infrastructure/runpod provider) ------------------
put_secret "yieldswarm/cloud/runpod" \
  api_key="${RUNPOD_API_KEY:-}"

# --- Vultr (vultr/vultr provider) ------------------------------------------
put_secret "yieldswarm/cloud/vultr" \
  api_key="${VULTR_API_KEY:-}"

# --- DigitalOcean (digitalocean/digitalocean provider) ----------------------
put_secret "yieldswarm/cloud/digitalocean" \
  token="${DIGITALOCEAN_TOKEN:-}" \
  spaces_access_id="${DIGITALOCEAN_SPACES_ACCESS_ID:-}" \
  spaces_secret_key="${DIGITALOCEAN_SPACES_SECRET_KEY:-}"

# --- RPC / blockchain endpoints --------------------------------------------
put_secret "yieldswarm/rpc/solana" \
  rpc_url="${SOLANA_RPC_URL:-}" \
  helius_api_key="${HELIUS_API_KEY:-}" \
  birdeye_api_key="${BIRDEYE_API_KEY:-}" \
  jupiter_api_key="${JUPITER_API_KEY:-}"

# --- Application runtime secrets (consumed by Akash workloads) --------------
put_secret "yieldswarm/app/core" \
  agentswarm_master_key="${AGENTSWARM_MASTER_KEY:-}" \
  kimiclaw_consensus_key="${KIMICLAW_CONSENSUS_KEY:-}" \
  wallet_encryption_key="${WALLET_ENCRYPTION_KEY:-}" \
  tee_signing_key="${TEE_SIGNING_KEY:-}" \
  database_encryption_key="${DATABASE_ENCRYPTION_KEY:-}"

put_secret "yieldswarm/app/llm" \
  openai_api_key="${OPENAI_API_KEY:-}" \
  anthropic_api_key="${ANTHROPIC_API_KEY:-}" \
  gemini_api_key="${GEMINI_API_KEY:-}" \
  grok_api_key="${GROK_API_KEY:-}"

log "Seeding complete. Review with: vault kv list -mount=${KV_MOUNT} yieldswarm/cloud"

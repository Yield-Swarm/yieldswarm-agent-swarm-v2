#!/usr/bin/env bash
# =============================================================================
# YieldSwarm Vault secret seeding
# -----------------------------------------------------------------------------
# Reads provider credentials from operator environment variables and writes
# them into the canonical KV v2 paths consumed by Terraform and the Akash
# runtime entrypoint.
#
# Run this ONCE on an air-gapped / TEE workstation. Never check the values in.
#
# Required env vars (will fail-fast if missing):
#   AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET
#   RUNPOD_API_KEY
#   VULTR_API_KEY
#   DIGITALOCEAN_TOKEN
#   SOLANA_RPC_URL, HELIUS_API_KEY, JUPITER_API_KEY, BIRDEYE_API_KEY,
#   RAYDIUM_API_KEY, TON_API_KEY, TAO_SUBNET_KEY, HELIX_CHAIN_BRIDGE_KEY,
#   ZEC_SHIELDED_KEY, ERC4337_BUNDLER_KEY
#
# Optional (akash + runtime):
#   AKASH_KEY_NAME, AKASH_KEYRING_BACKEND, AKASH_NODE, AKASH_CHAIN_ID,
#   AKASH_WALLET_MNEMONIC
#   AGENTSWARM_MASTER_KEY, KIMICLAW_CONSENSUS_KEY, GROK_API_KEY,
#   OPENAI_API_KEY, GEMINI_API_KEY, ANTHROPIC_API_KEY, WALLET_ENCRYPTION_KEY,
#   TEE_SIGNING_KEY, DATABASE_ENCRYPTION_KEY
# =============================================================================

set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set (secrets-admin policy)}"

require() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    printf 'ERROR: env var %s is required\n' "$var" >&2
    exit 2
  fi
}

log() { printf '\033[1;32m[seed]\033[0m %s\n' "$*"; }

# --- Azure -------------------------------------------------------------------
require AZURE_SUBSCRIPTION_ID
require AZURE_TENANT_ID
require AZURE_CLIENT_ID
require AZURE_CLIENT_SECRET
log "kv/yieldswarm/infra/azure"
vault kv put kv/yieldswarm/infra/azure \
  subscription_id="${AZURE_SUBSCRIPTION_ID}" \
  tenant_id="${AZURE_TENANT_ID}" \
  client_id="${AZURE_CLIENT_ID}" \
  client_secret="${AZURE_CLIENT_SECRET}" \
  resource_group="${AZURE_RESOURCE_GROUP:-yieldswarm-rg}" \
  location="${AZURE_LOCATION:-eastus}" >/dev/null

# --- RunPod ------------------------------------------------------------------
require RUNPOD_API_KEY
log "kv/yieldswarm/infra/runpod"
vault kv put kv/yieldswarm/infra/runpod \
  api_key="${RUNPOD_API_KEY}" \
  api_url="${RUNPOD_API_URL:-https://api.runpod.io/graphql}" \
  default_gpu_type="${RUNPOD_DEFAULT_GPU_TYPE:-NVIDIA RTX 4090}" \
  network_volume_id="${RUNPOD_NETWORK_VOLUME_ID:-}" >/dev/null

# --- Vultr -------------------------------------------------------------------
require VULTR_API_KEY
log "kv/yieldswarm/infra/vultr"
vault kv put kv/yieldswarm/infra/vultr \
  api_key="${VULTR_API_KEY}" \
  default_region="${VULTR_DEFAULT_REGION:-ewr}" \
  default_plan="${VULTR_DEFAULT_PLAN:-vc2-2c-4gb}" \
  ssh_key_id="${VULTR_SSH_KEY_ID:-}" >/dev/null

# --- DigitalOcean ------------------------------------------------------------
require DIGITALOCEAN_TOKEN
log "kv/yieldswarm/infra/digitalocean"
vault kv put kv/yieldswarm/infra/digitalocean \
  token="${DIGITALOCEAN_TOKEN}" \
  spaces_access_key="${DO_SPACES_ACCESS_KEY:-}" \
  spaces_secret_key="${DO_SPACES_SECRET_KEY:-}" \
  default_region="${DO_DEFAULT_REGION:-nyc3}" \
  default_size="${DO_DEFAULT_SIZE:-s-2vcpu-4gb}" \
  ssh_key_fingerprint="${DO_SSH_KEY_FINGERPRINT:-}" >/dev/null

# --- RPC + chain endpoints ---------------------------------------------------
require SOLANA_RPC_URL
require HELIUS_API_KEY
log "kv/yieldswarm/rpc"
vault kv put kv/yieldswarm/rpc \
  solana_rpc_url="${SOLANA_RPC_URL}" \
  helius_api_key="${HELIUS_API_KEY}" \
  jupiter_api_key="${JUPITER_API_KEY:-}" \
  birdeye_api_key="${BIRDEYE_API_KEY:-}" \
  raydium_api_key="${RAYDIUM_API_KEY:-}" \
  ton_api_key="${TON_API_KEY:-}" \
  tao_subnet_key="${TAO_SUBNET_KEY:-}" \
  helix_chain_bridge_key="${HELIX_CHAIN_BRIDGE_KEY:-}" \
  zec_shielded_key="${ZEC_SHIELDED_KEY:-}" \
  erc4337_bundler_key="${ERC4337_BUNDLER_KEY:-}" \
  failover_rpc_list="${FAILOVER_RPC_LIST:-[]}" >/dev/null

# --- Akash CLI bootstrap (optional) ------------------------------------------
if [[ -n "${AKASH_WALLET_MNEMONIC:-}" ]]; then
  log "kv/yieldswarm/runtime/akash"
  vault kv put kv/yieldswarm/runtime/akash \
    key_name="${AKASH_KEY_NAME:-yieldswarm}" \
    keyring_backend="${AKASH_KEYRING_BACKEND:-os}" \
    node="${AKASH_NODE:-https://rpc.akashnet.net:443}" \
    chain_id="${AKASH_CHAIN_ID:-akashnet-2}" \
    wallet_mnemonic="${AKASH_WALLET_MNEMONIC}" >/dev/null
else
  log "skipping kv/yieldswarm/runtime/akash (AKASH_WALLET_MNEMONIC not set)"
fi

# --- OpenClaw / AgentSwarm runtime secrets (optional but recommended) -------
if [[ -n "${AGENTSWARM_MASTER_KEY:-}" ]]; then
  log "kv/yieldswarm/runtime/openclaw"
  vault kv put kv/yieldswarm/runtime/openclaw \
    AGENTSWARM_MASTER_KEY="${AGENTSWARM_MASTER_KEY}" \
    KIMICLAW_CONSENSUS_KEY="${KIMICLAW_CONSENSUS_KEY:-}" \
    GROK_API_KEY="${GROK_API_KEY:-}" \
    OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
    GEMINI_API_KEY="${GEMINI_API_KEY:-}" \
    ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    WALLET_ENCRYPTION_KEY="${WALLET_ENCRYPTION_KEY:-}" \
    TEE_SIGNING_KEY="${TEE_SIGNING_KEY:-}" \
    DATABASE_ENCRYPTION_KEY="${DATABASE_ENCRYPTION_KEY:-}" >/dev/null
else
  log "skipping kv/yieldswarm/runtime/openclaw (AGENTSWARM_MASTER_KEY not set)"
fi

log "all requested secrets seeded into Vault at ${VAULT_ADDR}"

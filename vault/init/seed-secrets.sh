#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# vault/init/seed-secrets.sh
# YieldSwarm AgentSwarm OS — Secret Seeding Template
#
# Fill in real values for every variable below, then run this script ONCE
# on an air-gapped or trusted machine.
#
# Prerequisites:
#   - VAULT_ADDR exported
#   - VAULT_TOKEN exported (root token or agentswarm-admin token)
#   - vault CLI installed
#
# SECURITY: Never commit this file with real values.
#            Use read -s or a secrets manager to inject values.
# ---------------------------------------------------------------------------
set -euo pipefail

log()  { echo "[seed] $*"; }
step() { echo; echo "=== $* ==="; }

# ---------------------------------------------------------------------------
# Validate connection
# ---------------------------------------------------------------------------
: "${VAULT_ADDR:?Set VAULT_ADDR before running this script}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN before running this script}"

vault status > /dev/null 2>&1 || {
  echo "ERROR: Cannot reach Vault at ${VAULT_ADDR}" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Helper — prompt for a secret value interactively and export it
# ---------------------------------------------------------------------------
ask() {
  local varname="$1" prompt="$2"
  if [[ -z "${!varname:-}" ]]; then
    read -r -s -p "  ${prompt}: " value
    echo
    eval "export ${varname}=\"\${value}\""
  fi
}

# ---------------------------------------------------------------------------
# agentswarm/core — master keys and encryption keys
# ---------------------------------------------------------------------------
step "agentswarm/core"

ask AGENTSWARM_MASTER_KEY     "AGENTSWARM_MASTER_KEY"
ask KIMICLAW_CONSENSUS_KEY    "KIMICLAW_CONSENSUS_KEY"
ask WALLET_ENCRYPTION_KEY     "WALLET_ENCRYPTION_KEY"
ask TEE_SIGNING_KEY           "TEE_SIGNING_KEY"
ask DATABASE_ENCRYPTION_KEY   "DATABASE_ENCRYPTION_KEY"

vault kv put secret/agentswarm/core \
  agentswarm_master_key="${AGENTSWARM_MASTER_KEY}" \
  kimiclaw_consensus_key="${KIMICLAW_CONSENSUS_KEY}" \
  wallet_encryption_key="${WALLET_ENCRYPTION_KEY}" \
  tee_signing_key="${TEE_SIGNING_KEY}" \
  database_encryption_key="${DATABASE_ENCRYPTION_KEY}"
log "agentswarm/core written"

# ---------------------------------------------------------------------------
# agentswarm/llm — LLM provider API keys
# ---------------------------------------------------------------------------
step "agentswarm/llm"

ask GROK_API_KEY       "GROK_API_KEY"
ask OPENAI_API_KEY     "OPENAI_API_KEY"
ask GEMINI_API_KEY     "GEMINI_API_KEY"
ask ANTHROPIC_API_KEY  "ANTHROPIC_API_KEY"

vault kv put secret/agentswarm/llm \
  grok_api_key="${GROK_API_KEY}" \
  openai_api_key="${OPENAI_API_KEY}" \
  gemini_api_key="${GEMINI_API_KEY}" \
  anthropic_api_key="${ANTHROPIC_API_KEY}"
log "agentswarm/llm written"

# ---------------------------------------------------------------------------
# agentswarm/rpc — Blockchain RPC endpoints and keys
# ---------------------------------------------------------------------------
step "agentswarm/rpc"

ask SOLANA_RPC_URL          "SOLANA_RPC_URL (e.g. https://mainnet.helius-rpc.com/?api-key=...)"
ask HELIUS_API_KEY          "HELIUS_API_KEY"
ask BIRDEYE_API_KEY         "BIRDEYE_API_KEY"
ask JUPITER_API_KEY         "JUPITER_API_KEY"
ask RAYDIUM_API_KEY         "RAYDIUM_API_KEY"
ask PUMP_FUN_DEPLOY_KEY     "PUMP_FUN_DEPLOY_KEY"
ask TON_API_KEY             "TON_API_KEY"
ask TAO_SUBNET_KEY          "TAO_SUBNET_KEY"
ask HELIX_CHAIN_BRIDGE_KEY  "HELIX_CHAIN_BRIDGE_KEY"
ask ZEC_SHIELDED_KEY        "ZEC_SHIELDED_KEY"
ask ERC4337_BUNDLER_KEY     "ERC4337_BUNDLER_KEY"

vault kv put secret/agentswarm/rpc \
  solana_rpc_url="${SOLANA_RPC_URL}" \
  helius_api_key="${HELIUS_API_KEY}" \
  birdeye_api_key="${BIRDEYE_API_KEY}" \
  jupiter_api_key="${JUPITER_API_KEY}" \
  raydium_api_key="${RAYDIUM_API_KEY}" \
  pump_fun_deploy_key="${PUMP_FUN_DEPLOY_KEY}" \
  ton_api_key="${TON_API_KEY}" \
  tao_subnet_key="${TAO_SUBNET_KEY}" \
  helix_chain_bridge_key="${HELIX_CHAIN_BRIDGE_KEY}" \
  zec_shielded_key="${ZEC_SHIELDED_KEY}" \
  erc4337_bundler_key="${ERC4337_BUNDLER_KEY}"
log "agentswarm/rpc written"

# ---------------------------------------------------------------------------
# agentswarm/cloud/azure — Azure service principal credentials
# ---------------------------------------------------------------------------
step "agentswarm/cloud/azure"

ask AZURE_SUBSCRIPTION_ID  "AZURE_SUBSCRIPTION_ID"
ask AZURE_TENANT_ID        "AZURE_TENANT_ID"
ask AZURE_CLIENT_ID        "AZURE_CLIENT_ID (service principal app ID)"
ask AZURE_CLIENT_SECRET    "AZURE_CLIENT_SECRET"
ask AZURE_RESOURCE_GROUP   "AZURE_RESOURCE_GROUP (e.g. agentswarm-rg)"
ask AZURE_LOCATION         "AZURE_LOCATION (e.g. eastus)"

vault kv put secret/agentswarm/cloud/azure \
  subscription_id="${AZURE_SUBSCRIPTION_ID}" \
  tenant_id="${AZURE_TENANT_ID}" \
  client_id="${AZURE_CLIENT_ID}" \
  client_secret="${AZURE_CLIENT_SECRET}" \
  resource_group="${AZURE_RESOURCE_GROUP}" \
  location="${AZURE_LOCATION}"
log "agentswarm/cloud/azure written"

# ---------------------------------------------------------------------------
# agentswarm/cloud/runpod — RunPod GPU cloud credentials
# ---------------------------------------------------------------------------
step "agentswarm/cloud/runpod"

ask RUNPOD_API_KEY     "RUNPOD_API_KEY"
ask RUNPOD_NETWORK_VOLUME_ID "RUNPOD_NETWORK_VOLUME_ID (leave blank if none)"

vault kv put secret/agentswarm/cloud/runpod \
  api_key="${RUNPOD_API_KEY}" \
  network_volume_id="${RUNPOD_NETWORK_VOLUME_ID:-}"
log "agentswarm/cloud/runpod written"

# ---------------------------------------------------------------------------
# agentswarm/cloud/vultr — Vultr VPS credentials
# ---------------------------------------------------------------------------
step "agentswarm/cloud/vultr"

ask VULTR_API_KEY  "VULTR_API_KEY"

vault kv put secret/agentswarm/cloud/vultr \
  api_key="${VULTR_API_KEY}"
log "agentswarm/cloud/vultr written"

# ---------------------------------------------------------------------------
# agentswarm/cloud/digitalocean — DigitalOcean credentials
# ---------------------------------------------------------------------------
step "agentswarm/cloud/digitalocean"

ask DO_TOKEN               "DO_TOKEN (personal access token)"
ask DO_SPACES_ACCESS_ID    "DO_SPACES_ACCESS_ID"
ask DO_SPACES_SECRET_KEY   "DO_SPACES_SECRET_KEY"

vault kv put secret/agentswarm/cloud/digitalocean \
  token="${DO_TOKEN}" \
  spaces_access_id="${DO_SPACES_ACCESS_ID}" \
  spaces_secret_key="${DO_SPACES_SECRET_KEY}"
log "agentswarm/cloud/digitalocean written"

# ---------------------------------------------------------------------------
# agentswarm/depin — DePIN hardware access keys
# ---------------------------------------------------------------------------
step "agentswarm/depin"

ask DEPIN_HELIUM_HOTSPOT_KEYS  "DEPIN_HELIUM_HOTSPOT_KEYS (JSON array)"
ask GPU_CLUSTER_KEYS           "GPU_CLUSTER_KEYS (JSON array)"
ask GRASS_NODE_KEYS            "GRASS_NODE_KEYS (JSON array)"
ask SMARTTHINGS_BRIDGE_TOKEN   "SMARTTHINGS_BRIDGE_TOKEN"
ask COLORADO_POWER_PERMIT_ID   "COLORADO_POWER_PERMIT_ID"
ask UTILITY_API_KEY            "UTILITY_API_KEY"

vault kv put secret/agentswarm/depin \
  depin_helium_hotspot_keys="${DEPIN_HELIUM_HOTSPOT_KEYS}" \
  gpu_cluster_keys="${GPU_CLUSTER_KEYS}" \
  grass_node_keys="${GRASS_NODE_KEYS}" \
  smartthings_bridge_token="${SMARTTHINGS_BRIDGE_TOKEN}" \
  colorado_power_permit_id="${COLORADO_POWER_PERMIT_ID}" \
  utility_api_key="${UTILITY_API_KEY}"
log "agentswarm/depin written"

# ---------------------------------------------------------------------------
# agentswarm/integrations — third-party service tokens
# ---------------------------------------------------------------------------
step "agentswarm/integrations"

ask NOTION_API_KEY      "NOTION_API_KEY"
ask LINEAR_API_KEY      "LINEAR_API_KEY"
ask VERCEL_API_TOKEN    "VERCEL_API_TOKEN"
ask GITHUB_TOKEN        "GITHUB_TOKEN"
ask TELEGRAM_BOT_TOKEN  "TELEGRAM_BOT_TOKEN"
ask FILECOIN_STORAGE_KEY "FILECOIN_STORAGE_KEY"
ask DEXSCREENER_API     "DEXSCREENER_API"
ask SOLSCAN_API_KEY     "SOLSCAN_API_KEY"

vault kv put secret/agentswarm/integrations \
  notion_api_key="${NOTION_API_KEY}" \
  linear_api_key="${LINEAR_API_KEY}" \
  vercel_api_token="${VERCEL_API_TOKEN}" \
  github_token="${GITHUB_TOKEN}" \
  telegram_bot_token="${TELEGRAM_BOT_TOKEN}" \
  filecoin_storage_key="${FILECOIN_STORAGE_KEY}" \
  dexscreener_api="${DEXSCREENER_API}" \
  solscan_api_key="${SOLSCAN_API_KEY}"
log "agentswarm/integrations written"

# ---------------------------------------------------------------------------
# agentswarm/payments — payment and domain credentials
# ---------------------------------------------------------------------------
step "agentswarm/payments"

ask UD_API_KEY           "UD_API_KEY (Unstoppable Domains)"
ask WISE_BUSINESS_EMAIL  "WISE_BUSINESS_EMAIL"

vault kv put secret/agentswarm/payments \
  ud_api_key="${UD_API_KEY}" \
  wise_business_email="${WISE_BUSINESS_EMAIL}"
log "agentswarm/payments written"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "=== All secrets seeded successfully ==="
echo
echo "Verify with:"
echo "  vault kv list secret/agentswarm/"
echo "  vault kv get secret/agentswarm/core"

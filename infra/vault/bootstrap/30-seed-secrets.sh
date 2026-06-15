#!/usr/bin/env bash
# Seed Vault with the secret payloads consumed by Terraform and the
# Akash runtime. This script reads every value from the environment
# (typically loaded from an air-gapped .env or TEE-managed file just
# before invocation) so no plaintext secret ever lives on disk inside
# the repo.
#
# Usage:
#   set -a; source /run/secrets/apn.env; set +a
#   VAULT_ADDR=https://vault.apn.internal:8200 \
#   VAULT_TOKEN=hvs.CAES... \
#     infra/vault/bootstrap/30-seed-secrets.sh
#
# The names match .env.example. Anything left empty is skipped, so
# this script is safe to run multiple times as new secrets are added.

set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

log() { printf '[seed] %s\n' "$*"; }

# put_secret <vault path> <key>=<env var> [<key>=<env var> ...]
# Writes a single KV v2 secret. Skips the call if every value is empty
# so partial inventories don't accidentally clobber existing data.
put_secret() {
  local path="$1"; shift
  local args=()
  local has_value=0
  for pair in "$@"; do
    local key="${pair%%=*}"
    local env_var="${pair#*=}"
    local value="${!env_var:-}"
    if [[ -n "${value}" ]]; then
      args+=("${key}=${value}")
      has_value=1
    fi
  done
  if [[ "${has_value}" -eq 0 ]]; then
    log "skip ${path} (no values present in environment)"
    return 0
  fi
  log "writing ${path} (${#args[@]} field(s))"
  vault kv put "${path}" "${args[@]}" >/dev/null
}

# ----- Provider credentials (consumed by Terraform) -----------------------

put_secret kv/apn/azure \
  subscription_id=AZURE_SUBSCRIPTION_ID \
  tenant_id=AZURE_TENANT_ID \
  client_id=AZURE_CLIENT_ID \
  client_secret=AZURE_CLIENT_SECRET \
  location=AZURE_LOCATION

put_secret kv/apn/runpod \
  api_key=RUNPOD_API_KEY \
  default_region=RUNPOD_DEFAULT_REGION

put_secret kv/apn/vultr \
  api_key=VULTR_API_KEY \
  default_region=VULTR_DEFAULT_REGION

put_secret kv/apn/digitalocean \
  token=DIGITALOCEAN_TOKEN \
  spaces_access_id=DIGITALOCEAN_SPACES_ACCESS_ID \
  spaces_secret_key=DIGITALOCEAN_SPACES_SECRET_KEY \
  default_region=DIGITALOCEAN_DEFAULT_REGION

# ----- RPC + chain API keys (consumed by Terraform + runtime) ------------

put_secret kv/apn/rpc/solana \
  rpc_url=SOLANA_RPC_URL \
  helius_api_key=HELIUS_API_KEY \
  birdeye_api_key=BIRDEYE_API_KEY \
  jupiter_api_key=JUPITER_API_KEY \
  raydium_api_key=RAYDIUM_API_KEY \
  pump_fun_deploy_key=PUMP_FUN_DEPLOY_KEY \
  failover_rpc_list=FAILOVER_RPC_LIST

put_secret kv/apn/rpc/eth \
  rpc_url=ETH_RPC_URL \
  erc4337_bundler_key=ERC4337_BUNDLER_KEY

put_secret kv/apn/rpc/ton \
  api_key=TON_API_KEY

put_secret kv/apn/rpc/tao \
  subnet_key=TAO_SUBNET_KEY \
  bittensor_node_staking_key=NG64_BITTENSOR_NODE_STAKING_KEY

put_secret kv/apn/rpc/helix \
  bridge_key=HELIX_CHAIN_BRIDGE_KEY

put_secret kv/apn/rpc/zec \
  shielded_key=ZEC_SHIELDED_KEY

# ----- Core platform secrets (consumed by runtime only) -------------------

put_secret kv/apn/core \
  master_key=AGENTSWARM_MASTER_KEY \
  kimiclaw_consensus_key=KIMICLAW_CONSENSUS_KEY \
  wallet_encryption_key=WALLET_ENCRYPTION_KEY \
  tee_signing_key=TEE_SIGNING_KEY \
  database_encryption_key=DATABASE_ENCRYPTION_KEY

# ----- LLM keys -----------------------------------------------------------

put_secret kv/apn/llm/openai     api_key=OPENAI_API_KEY
put_secret kv/apn/llm/anthropic  api_key=ANTHROPIC_API_KEY
put_secret kv/apn/llm/gemini     api_key=GEMINI_API_KEY
put_secret kv/apn/llm/grok       api_key=GROK_API_KEY
put_secret kv/apn/llm/arena      api_key=QUARANTINED_LLM_ARENA_KEY
put_secret kv/apn/llm/zkml       verifier_key=ZKML_VERIFIER_KEY

# ----- Integrations -------------------------------------------------------

put_secret kv/apn/integrations/notion    api_key=NOTION_API_KEY
put_secret kv/apn/integrations/linear    api_key=LINEAR_API_KEY
put_secret kv/apn/integrations/vercel    api_token=VERCEL_API_TOKEN
put_secret kv/apn/integrations/github    token=GITHUB_TOKEN
put_secret kv/apn/integrations/telegram  bot_token=TELEGRAM_BOT_TOKEN
put_secret kv/apn/integrations/x         api_keys=X_API_KEYS
put_secret kv/apn/integrations/meta_ads  token=META_ADS_TOKEN
put_secret kv/apn/integrations/ud        api_key=UD_API_KEY
put_secret kv/apn/integrations/sp        api_key=S_AND_P_API_KEY
put_secret kv/apn/integrations/dexscreener api_key=DEXSCREENER_API
put_secret kv/apn/integrations/solscan   api_key=SOLSCAN_API_KEY
put_secret kv/apn/integrations/filecoin  storage_key=FILECOIN_STORAGE_KEY

# ----- DePIN + hardware ---------------------------------------------------

put_secret kv/apn/depin/helium      hotspot_keys=DEPIN_HELIUM_HOTSPOT_KEYS
put_secret kv/apn/depin/gpu         cluster_keys=GPU_CLUSTER_KEYS
put_secret kv/apn/depin/grass       node_keys=GRASS_NODE_KEYS
put_secret kv/apn/depin/smartthings bridge_token=SMARTTHINGS_BRIDGE_TOKEN
put_secret kv/apn/depin/utility \
  api_key=UTILITY_API_KEY \
  colorado_power_permit_id=COLORADO_POWER_PERMIT_ID
put_secret kv/apn/depin/tesla \
  integration_token=TESLA_INTEGRATION_TOKEN \
  fsd_data_feed_key=FSD_DATA_FEED_KEY

log "seed complete"

#!/usr/bin/env bash
# akash/entrypoint.sh  (also used as docker/entrypoint.sh)
#
# Runtime secret injection for YieldSwarm AgentSwarm OS v2.
# This script runs inside the container as PID 1's bootstrap step.
#
# Security model:
#   - Only VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID are present in the
#     container/pod environment (set in Akash SDL or docker run -e flags).
#   - All other secrets are fetched from Vault at startup using a short-lived
#     token obtained via AppRole login.
#   - The Vault token is stored only in this process's environment and is
#     never written to disk or logged.
#   - Once all secrets are exported, the Vault token is unset.
#   - The script ends by exec'ing the actual application command, replacing
#     this shell process so the PID 1 is the application, not bash.
#
# Usage (Docker):
#   docker run \
#     -e VAULT_ADDR="https://vault.yieldswarm.io:8200" \
#     -e VAULT_ROLE_ID="<role-id>" \
#     -e VAULT_SECRET_ID="<secret-id>" \
#     yieldswarm/agent-swarm:latest
#
# Usage (Akash SDL):
#   env:
#     - VAULT_ADDR=https://vault.yieldswarm.io:8200
#     - VAULT_ROLE_ID=<role-id>
#     - VAULT_SECRET_ID=<secret-id>

set -euo pipefail

_log()  { echo "[entrypoint] $*" >&2; }
_fail() { echo "[entrypoint][FATAL] $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 0. Verify required Vault inputs are present
# ---------------------------------------------------------------------------
: "${VAULT_ADDR:?'VAULT_ADDR is required — set it in Akash SDL / docker run env'}"
: "${VAULT_ROLE_ID:?'VAULT_ROLE_ID is required'}"
: "${VAULT_SECRET_ID:?'VAULT_SECRET_ID is required'}"

_log "Vault address: ${VAULT_ADDR}"

# ---------------------------------------------------------------------------
# 1. Wait for Vault to be reachable (retry up to 30s)
# ---------------------------------------------------------------------------
_log "Waiting for Vault to be reachable..."
MAX_WAIT=30
ELAPSED=0
until curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; do
  if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    _fail "Vault at ${VAULT_ADDR} is not reachable after ${MAX_WAIT}s."
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done
_log "Vault is reachable."

# ---------------------------------------------------------------------------
# 2. AppRole login — obtain a short-lived Vault token
# ---------------------------------------------------------------------------
_log "Authenticating to Vault via AppRole..."
LOGIN_RESPONSE=$(curl -sf \
  --request POST \
  --data "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"${VAULT_SECRET_ID}\"}" \
  "${VAULT_ADDR}/v1/auth/approle/login") \
  || _fail "AppRole login failed. Verify VAULT_ROLE_ID and VAULT_SECRET_ID."

VAULT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.auth.client_token') \
  || _fail "Could not parse Vault token from login response."

[[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]] \
  && _fail "Vault returned an empty token — check AppRole credentials and policy."

export VAULT_TOKEN
_log "Vault token obtained."

# ---------------------------------------------------------------------------
# Helper: read one KV v2 secret, return JSON data block
# ---------------------------------------------------------------------------
_read_secret() {
  local path="$1"
  local response
  response=$(curl -sf \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/secret/data/${path}") \
    || { echo "{}"; return; }
  echo "$response" | jq -r '.data.data // {}'
}

# ---------------------------------------------------------------------------
# 3. Fetch agent master secrets (LLM API keys, encryption keys)
# ---------------------------------------------------------------------------
_log "Fetching agents/master secrets..."
MASTER=$(  _read_secret "agents/master")

export AGENTSWARM_MASTER_KEY=$(   echo "$MASTER" | jq -r '.agentswarm_master_key   // ""')
export KIMICLAW_CONSENSUS_KEY=$(  echo "$MASTER" | jq -r '.kimiclaw_consensus_key  // ""')
export WALLET_ENCRYPTION_KEY=$(   echo "$MASTER" | jq -r '.wallet_encryption_key   // ""')
export TEE_SIGNING_KEY=$(         echo "$MASTER" | jq -r '.tee_signing_key         // ""')
export DATABASE_ENCRYPTION_KEY=$( echo "$MASTER" | jq -r '.database_encryption_key // ""')
export GROK_API_KEY=$(            echo "$MASTER" | jq -r '.grok_api_key            // ""')
export OPENAI_API_KEY=$(          echo "$MASTER" | jq -r '.openai_api_key          // ""')
export GEMINI_API_KEY=$(          echo "$MASTER" | jq -r '.gemini_api_key          // ""')
export ANTHROPIC_API_KEY=$(       echo "$MASTER" | jq -r '.anthropic_api_key       // ""')

# ---------------------------------------------------------------------------
# 4. Fetch blockchain / wallet secrets
# ---------------------------------------------------------------------------
_log "Fetching agents/blockchain secrets..."
BLOCKCHAIN=$(_read_secret "agents/blockchain")

export APN_MINT_ADDRESS=$(              echo "$BLOCKCHAIN" | jq -r '.apn_mint_address              // ""')
export PUMP_FUN_COIN_ID=$(              echo "$BLOCKCHAIN" | jq -r '.pump_fun_coin_id              // ""')
export RAYDIUM_POOL_ID=$(               echo "$BLOCKCHAIN" | jq -r '.raydium_pool_id              // ""')
export LP_TOKEN_ADDRESS=$(              echo "$BLOCKCHAIN" | jq -r '.lp_token_address             // ""')
export NG64_BITTENSOR_NODE_STAKING_KEY=$(echo "$BLOCKCHAIN"| jq -r '.ng64_bittensor_node_staking_key // ""')
export ZKML_VERIFIER_KEY=$(             echo "$BLOCKCHAIN" | jq -r '.zkml_verifier_key            // ""')

# ---------------------------------------------------------------------------
# 5. Fetch DePIN node keys
# ---------------------------------------------------------------------------
_log "Fetching agents/depin secrets..."
DEPIN=$(_read_secret "agents/depin")

export DEPIN_HELIUM_HOTSPOT_KEYS=$(echo "$DEPIN" | jq -r '.depin_helium_hotspot_keys // "[]"')
export GPU_CLUSTER_KEYS=$(         echo "$DEPIN" | jq -r '.gpu_cluster_keys          // "[]"')
export GRASS_NODE_KEYS=$(          echo "$DEPIN" | jq -r '.grass_node_keys           // "[]"')
export SMARTTHINGS_BRIDGE_TOKEN=$( echo "$DEPIN" | jq -r '.smartthings_bridge_token  // ""')
export COLORADO_POWER_PERMIT_ID=$( echo "$DEPIN" | jq -r '.colorado_power_permit_id  // ""')
export UTILITY_API_KEY=$(          echo "$DEPIN" | jq -r '.utility_api_key           // ""')

# ---------------------------------------------------------------------------
# 6. Fetch integration API keys
# ---------------------------------------------------------------------------
_log "Fetching agents/integrations secrets..."
INTEGRATIONS=$(_read_secret "agents/integrations")

export NOTION_API_KEY=$(             echo "$INTEGRATIONS" | jq -r '.notion_api_key             // ""')
export LINEAR_API_KEY=$(             echo "$INTEGRATIONS" | jq -r '.linear_api_key             // ""')
export VERCEL_API_TOKEN=$(           echo "$INTEGRATIONS" | jq -r '.vercel_api_token           // ""')
export GITHUB_TOKEN=$(               echo "$INTEGRATIONS" | jq -r '.github_token              // ""')
export TELEGRAM_BOT_TOKEN=$(         echo "$INTEGRATIONS" | jq -r '.telegram_bot_token        // ""')
export UD_API_KEY=$(                 echo "$INTEGRATIONS" | jq -r '.ud_api_key                // ""')
export DEXSCREENER_API=$(            echo "$INTEGRATIONS" | jq -r '.dexscreener_api           // ""')
export FILECOIN_STORAGE_KEY=$(       echo "$INTEGRATIONS" | jq -r '.filecoin_storage_key      // ""')
export QUARANTINED_LLM_ARENA_KEY=$(  echo "$INTEGRATIONS" | jq -r '.quarantined_llm_arena_key // ""')

# ---------------------------------------------------------------------------
# 7. Fetch Solana RPC secrets
# ---------------------------------------------------------------------------
_log "Fetching rpc/solana secrets..."
RPC_SOLANA=$(_read_secret "rpc/solana")

export SOLANA_RPC_URL=$(    echo "$RPC_SOLANA" | jq -r '.endpoint        // "https://api.mainnet-beta.solana.com"')
export HELIUS_API_KEY=$(    echo "$RPC_SOLANA" | jq -r '.helius_api_key  // ""')
export BIRDEYE_API_KEY=$(   echo "$RPC_SOLANA" | jq -r '.birdeye_api_key // ""')
export JUPITER_API_KEY=$(   echo "$RPC_SOLANA" | jq -r '.jupiter_api_key // ""')
export RAYDIUM_API_KEY=$(   echo "$RPC_SOLANA" | jq -r '.raydium_api_key // ""')
export PUMP_FUN_DEPLOY_KEY=$(echo "$RPC_SOLANA"| jq -r '.pump_fun_deploy_key // ""')
export SOLSCAN_API_KEY=$(   echo "$RPC_SOLANA" | jq -r '.solscan_api_key // ""')
export FAILOVER_RPC_LIST=$( echo "$RPC_SOLANA" | jq -r '.failover_rpc_list // "[]"')

# ---------------------------------------------------------------------------
# 8. Fetch EVM / other-chain RPC secrets
# ---------------------------------------------------------------------------
_log "Fetching rpc/evm secrets..."
RPC_EVM=$(_read_secret "rpc/evm")

export TON_API_KEY=$(           echo "$RPC_EVM" | jq -r '.ton_api_key            // ""')
export TAO_SUBNET_KEY=$(        echo "$RPC_EVM" | jq -r '.tao_subnet_key         // ""')
export HELIX_CHAIN_BRIDGE_KEY=$(echo "$RPC_EVM" | jq -r '.helix_chain_bridge_key // ""')
export ZEC_SHIELDED_KEY=$(      echo "$RPC_EVM" | jq -r '.zec_shielded_key       // ""')
export ERC4337_BUNDLER_KEY=$(   echo "$RPC_EVM" | jq -r '.erc4337_bundler_key    // ""')

# ---------------------------------------------------------------------------
# 9. Revoke the Vault token — it's no longer needed
# ---------------------------------------------------------------------------
_log "Revoking Vault token..."
curl -sf \
  --request POST \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/auth/token/revoke-self" > /dev/null 2>&1 || true

unset VAULT_TOKEN
unset VAULT_ROLE_ID
unset VAULT_SECRET_ID
_log "Vault token revoked and credentials cleared from environment."

# ---------------------------------------------------------------------------
# 10. Set safe non-secret defaults
# ---------------------------------------------------------------------------
export AGENT_COUNT_TOTAL="${AGENT_COUNT_TOTAL:-10080}"
export AGENTS_PER_SHARD="${AGENTS_PER_SHARD:-84}"
export AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"
export CRON_SHARD_COUNT="${CRON_SHARD_COUNT:-120}"
export CRON_INTERVAL_MINUTES="${CRON_INTERVAL_MINUTES:-15}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export NETWORK_LOCKDOWN_MODE="${NETWORK_LOCKDOWN_MODE:-true}"
export SLIPPAGE_TOLERANCE="${SLIPPAGE_TOLERANCE:-0.005}"
export MAX_FEE_PERCENT="${MAX_FEE_PERCENT:-0.01}"
export IMPERMANENT_LOSS_THRESHOLD="${IMPERMANENT_LOSS_THRESHOLD:-0.1}"
export MAYHEM_MODE_ENABLED="${MAYHEM_MODE_ENABLED:-false}"
export IPFS_GATEWAY="${IPFS_GATEWAY:-https://ipfs.io}"
export BACKUP_CRON_INTERVAL="${BACKUP_CRON_INTERVAL:-1440}"
export BUG_BOUNTY_AGENT_ENABLED="${BUG_BOUNTY_AGENT_ENABLED:-true}"

_log "All secrets loaded. Starting application..."

# ---------------------------------------------------------------------------
# 11. Exec the application (replaces this shell as PID 1)
# ---------------------------------------------------------------------------
if [[ $# -gt 0 ]]; then
  exec "$@"
else
  # Default: run the agent swarm Python process
  exec python -u /app/agents/akash-optimizer.py
fi

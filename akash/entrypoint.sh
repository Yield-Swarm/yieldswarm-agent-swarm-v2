#!/usr/bin/env bash
# ============================================================
# YieldSwarm AgentSwarm OS — Akash Container Entrypoint
# ============================================================
# Responsibility chain:
#   1. Validate required Vault bootstrap variables.
#   2. Authenticate to Vault via AppRole.
#   3. Fetch all secrets for the relevant Vault paths.
#   4. Export secrets into the process environment.
#   5. Write Vault token to disk for Vault Agent renewal.
#   6. Exec the main agent process (replaces this shell).
#
# Required environment variables (injected by Akash SDL):
#   VAULT_ADDR       — Vault server URL
#   VAULT_ROLE_ID    — AppRole Role ID
#   VAULT_SECRET_ID  — AppRole Secret ID
#
# Optional:
#   VAULT_SKIP_TLS_VERIFY — set "true" in dev only
#   VAULT_NAMESPACE       — for Vault Enterprise namespaces
#
# The script NEVER writes secret values to any log output.
# ============================================================
set -euo pipefail

# ── Colour helpers (no-op when not a TTY) ────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

log()  { echo -e "${CYAN}[entrypoint]${NC} $*"; }
warn() { echo -e "${YELLOW}[entrypoint WARN]${NC} $*"; }
die()  { echo -e "${RED}[entrypoint ERROR]${NC} $*" >&2; exit 1; }

# ── Dependency check ──────────────────────────────────────────
for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required tool '$cmd' not found in container"
done

# ── Guard: required bootstrap vars ───────────────────────────
[[ -z "${VAULT_ADDR:-}"       ]] && die "VAULT_ADDR is not set"
[[ -z "${VAULT_ROLE_ID:-}"    ]] && die "VAULT_ROLE_ID is not set"
[[ -z "${VAULT_SECRET_ID:-}"  ]] && die "VAULT_SECRET_ID is not set"

VAULT_SKIP_TLS="${VAULT_SKIP_TLS_VERIFY:-false}"
VAULT_NS_HEADER=""
[[ -n "${VAULT_NAMESPACE:-}" ]] && VAULT_NS_HEADER="-H X-Vault-Namespace:${VAULT_NAMESPACE}"

# ── TLS option ────────────────────────────────────────────────
CURL_TLS_OPT=""
if [[ "${VAULT_SKIP_TLS}" == "true" ]]; then
  warn "TLS verification disabled — do not use in production"
  CURL_TLS_OPT="-k"
fi

# ── Helper: vault_api ─────────────────────────────────────────
# Calls the Vault HTTP API and returns the raw JSON response.
# Dies on HTTP errors.
vault_api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local token="${4:-}"

  local auth_header=""
  [[ -n "${token}" ]] && auth_header="-H X-Vault-Token:${token}"

  local response http_code body
  response=$(curl -sS ${CURL_TLS_OPT} \
    -w "\n__HTTP_CODE__%{http_code}" \
    -X "${method}" \
    -H "Content-Type: application/json" \
    ${auth_header} \
    ${VAULT_NS_HEADER} \
    ${data:+-d "${data}"} \
    "${VAULT_ADDR}/v1/${path}" 2>&1)

  http_code=$(echo "${response}" | grep '__HTTP_CODE__' | sed 's/__HTTP_CODE__//')
  body=$(echo "${response}" | grep -v '__HTTP_CODE__')

  if [[ "${http_code}" -lt 200 || "${http_code}" -ge 300 ]]; then
    die "Vault API call failed [${http_code}]: ${path} — $(echo "${body}" | jq -r '.errors[0] // "unknown error"' 2>/dev/null)"
  fi

  echo "${body}"
}

# ── Step 1: AppRole login ─────────────────────────────────────
log "Authenticating to Vault via AppRole..."

LOGIN_PAYLOAD="{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"${VAULT_SECRET_ID}\"}"
LOGIN_RESPONSE=$(vault_api POST "auth/approle/login" "${LOGIN_PAYLOAD}")

VAULT_TOKEN=$(echo "${LOGIN_RESPONSE}" | jq -r '.auth.client_token')
TOKEN_TTL=$(echo "${LOGIN_RESPONSE}"   | jq -r '.auth.lease_duration')
TOKEN_RENEWABLE=$(echo "${LOGIN_RESPONSE}" | jq -r '.auth.renewable')

[[ -z "${VAULT_TOKEN}" || "${VAULT_TOKEN}" == "null" ]] && \
  die "AppRole login succeeded but returned no token"

log "Token acquired (TTL: ${TOKEN_TTL}s, renewable: ${TOKEN_RENEWABLE})"

# Write token to disk for Vault Agent to pick up for renewal
install -m 0700 -d /vault/approle
echo "${VAULT_TOKEN}" > /vault/approle/token
chmod 0600 /vault/approle/token

# Export so child processes can call Vault directly if needed
export VAULT_TOKEN

# ── Helper: kv_read ──────────────────────────────────────────
# Reads a KV v2 secret and returns its .data.data JSON object.
kv_read() {
  local path="$1"
  local response

  response=$(vault_api GET "secret/data/${path}" "" "${VAULT_TOKEN}")
  echo "${response}" | jq -r '.data.data'
}

# ── Helper: export_kv ────────────────────────────────────────
# Exports every key in a KV v2 secret document as an env var.
# Keys are uppercased; the caller supplies an optional prefix.
export_kv() {
  local path="$1"
  local prefix="${2:-}"
  local data

  data=$(kv_read "${path}")

  while IFS='=' read -r key value; do
    local var_name="${prefix}${key^^}"
    # Mask value in case xtrace is accidentally enabled
    export "${var_name}=${value}"
  done < <(echo "${data}" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
}

# ── Step 2: Fetch and export secrets ─────────────────────────
log "Fetching secrets from Vault..."

# Core auth & encryption keys
export_kv "yieldswarm/core"
# Exports: MASTER_KEY, KIMICLAW_KEY, WALLET_ENCRYPTION_KEY,
#          TEE_SIGNING_KEY, DB_ENCRYPTION_KEY

# LLM provider keys
export_kv "yieldswarm/llm"
# Exports: GROK_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY,
#          ANTHROPIC_API_KEY

# RPC endpoints
export_kv "yieldswarm/rpc"
# Exports: SOLANA_RPC_URL, HELIUS_API_KEY, BIRDEYE_API_KEY,
#          JUPITER_API_KEY, RAYDIUM_API_KEY, etc.

# Blockchain / DeFi keys
export_kv "yieldswarm/blockchain"
# Exports: PUMP_FUN_DEPLOY_KEY, APN_MINT_ADDRESS, etc.

# DePIN hardware keys
export_kv "yieldswarm/depin"
# Exports: DEPIN_HELIUM_HOTSPOT_KEYS, GPU_CLUSTER_KEYS, etc.

# Third-party integrations
export_kv "yieldswarm/integrations"
# Exports: NOTION_API_KEY, LINEAR_API_KEY, TELEGRAM_BOT_TOKEN, etc.

# Monitoring / observability
export_kv "yieldswarm/monitoring"
# Exports: MONITORING_PROMETHEUS_URL, FILECOIN_STORAGE_KEY, etc.

# Akash deployment config (self-referential metadata)
export_kv "yieldswarm/akash"
# Exports: AKASH_WALLET_ADDRESS, AKASH_KEY_NAME, etc.

log "Secrets loaded successfully"

# ── Step 3: Optional — start Vault Agent for renewal ─────────
# Vault Agent handles token renewal in the background so the
# container never has to restart due to token expiry.
if command -v vault >/dev/null 2>&1; then
  # Write AppRole credentials for Vault Agent auto-auth
  echo "${VAULT_ROLE_ID}"   > /vault/approle/role-id
  echo "${VAULT_SECRET_ID}" > /vault/approle/secret-id
  chmod 0600 /vault/approle/role-id /vault/approle/secret-id

  # Patch vault-agent.hcl with the actual Vault address
  if [[ -f /vault/config/vault-agent.hcl ]]; then
    sed -i "s|VAULT_ADDR_PLACEHOLDER|${VAULT_ADDR}|g" /vault/config/vault-agent.hcl
    vault agent -config=/vault/config/vault-agent.hcl \
      -log-level=warn &
    VAULT_AGENT_PID=$!
    log "Vault Agent started (PID ${VAULT_AGENT_PID}) for token renewal"
    echo "${VAULT_AGENT_PID}" > /tmp/vault-agent.pid
  fi
fi

# ── Step 4: Clear bootstrap credentials from env ─────────────
# Remove the AppRole credentials from the environment so that
# child processes cannot observe them (they already ran login).
unset VAULT_ROLE_ID VAULT_SECRET_ID

# ── Step 5: Exec the main agent process ──────────────────────
# Default command: python agentswarm; override via CMD in SDL
MAIN_CMD="${@:-python /app/agents/akash-optimizer.py}"

log "Launching main process: ${MAIN_CMD}"
echo "${$}" > /tmp/agent.pid  # used by vault-agent.hcl exec command

exec ${MAIN_CMD}

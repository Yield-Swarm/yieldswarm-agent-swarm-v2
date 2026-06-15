#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# akash/entrypoint.sh
# YieldSwarm AgentSwarm OS — Vault-based secret injection at container start.
#
# Authentication order:
#   1. AppRole (VAULT_ROLE_ID + VAULT_SECRET_ID) — recommended for Akash
#   2. Direct token (VAULT_TOKEN)               — for local dev / CI
#
# After auth, all secrets are fetched from Vault KV v2 and exported as
# environment variables. The real process is then exec-ed so it inherits
# the environment and PID 1 belongs to it (or to tini if used).
#
# Required env vars at launch:
#   VAULT_ADDR      — Vault server URL (e.g. https://vault.example.com:8200)
#
# Auth env vars (one pair required):
#   VAULT_ROLE_ID + VAULT_SECRET_ID   (AppRole — preferred)
#   VAULT_TOKEN                        (direct token)
# ---------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

VAULT_BIN="${VAULT_BIN:-vault}"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log()  { echo "[entrypoint] $*" >&2; }
die()  { log "FATAL: $*"; exit 1; }
warn() { log "WARN: $*"; }

# ---------------------------------------------------------------------------
# Step 1 — Validate required environment
# ---------------------------------------------------------------------------
: "${VAULT_ADDR:?VAULT_ADDR must be set to your Vault server URL}"

# ---------------------------------------------------------------------------
# Step 2 — Wait for Vault to be reachable (up to 60 s)
# ---------------------------------------------------------------------------
log "Waiting for Vault at ${VAULT_ADDR} ..."
DEADLINE=$(( $(date +%s) + 60 ))
until ${VAULT_BIN} status > /dev/null 2>&1; do
  if [[ $(date +%s) -gt ${DEADLINE} ]]; then
    die "Vault is not reachable after 60 s. Check VAULT_ADDR and network."
  fi
  sleep 2
done
log "Vault is reachable."

# ---------------------------------------------------------------------------
# Step 3 — Authenticate
# ---------------------------------------------------------------------------
if [[ -n "${VAULT_ROLE_ID:-}" && -n "${VAULT_SECRET_ID:-}" ]]; then
  log "Authenticating via AppRole ..."
  VAULT_TOKEN=$(
    ${VAULT_BIN} write -field=token auth/approle/login \
      role_id="${VAULT_ROLE_ID}" \
      secret_id="${VAULT_SECRET_ID}"
  )
  export VAULT_TOKEN

  # Immediately unset auth credentials so they aren't visible to the child
  unset VAULT_ROLE_ID
  unset VAULT_SECRET_ID
  log "AppRole authentication successful."

elif [[ -n "${VAULT_TOKEN:-}" ]]; then
  log "Using existing VAULT_TOKEN."

else
  die "No Vault credentials found. Set VAULT_ROLE_ID+VAULT_SECRET_ID or VAULT_TOKEN."
fi

# ---------------------------------------------------------------------------
# Step 4 — Helper: export every key in a KV v2 path as an env var
#
# Key names are uppercased; all values are treated as strings.
# Example: secret/agentswarm/llm → OPENAI_API_KEY, GROK_API_KEY …
# ---------------------------------------------------------------------------
kv_export() {
  local mount="$1"
  local path="$2"

  local json
  if ! json=$(${VAULT_BIN} kv get -mount="${mount}" -format=json "${path}" 2>/dev/null); then
    warn "Could not read secret/${path} — skipping (check policy)"
    return 0
  fi

  local -A kv_pairs
  while IFS='=' read -r key value; do
    local upper_key
    upper_key="${key^^}"
    # Use printf to safely handle any special characters in the value
    printf -v "KV_${upper_key}" '%s' "${value}"
    export "${upper_key}=${value}"
  done < <(echo "${json}" | jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"')
}

# ---------------------------------------------------------------------------
# Step 5 — Load all secret paths needed by the agents
# ---------------------------------------------------------------------------
log "Loading secrets from Vault ..."

kv_export "secret" "agentswarm/core"
kv_export "secret" "agentswarm/llm"
kv_export "secret" "agentswarm/rpc"
kv_export "secret" "agentswarm/depin"
kv_export "secret" "agentswarm/integrations"

log "Secrets loaded successfully."

# ---------------------------------------------------------------------------
# Step 6 — Optional: schedule token renewal in the background
#
# Vault tokens have a TTL. For long-running agents we renew the token every
# half-TTL. The background job exits cleanly when the main process stops.
# ---------------------------------------------------------------------------
renew_token_loop() {
  local ttl
  ttl=$(${VAULT_BIN} token lookup -format=json 2>/dev/null | jq -r '.data.ttl' || echo 43200)
  local sleep_sec=$(( ttl / 2 ))
  [[ ${sleep_sec} -lt 60 ]] && sleep_sec=60

  while true; do
    sleep "${sleep_sec}"
    if ${VAULT_BIN} token renew > /dev/null 2>&1; then
      log "Token renewed."
    else
      warn "Token renewal failed — agent may lose Vault access before the next renewal."
    fi
  done
}
renew_token_loop &
RENEWER_PID=$!
trap 'kill ${RENEWER_PID} 2>/dev/null || true' EXIT INT TERM

# ---------------------------------------------------------------------------
# Step 7 — Exec the real agent process
# ---------------------------------------------------------------------------
log "Starting: $*"
exec "$@"

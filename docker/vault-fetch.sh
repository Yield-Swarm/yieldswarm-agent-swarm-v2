#!/usr/bin/env bash
# Fetch secrets from HashiCorp Vault and export as environment variables.
# Called by entrypoint.sh before starting the agent process.
#
# Required env:
#   VAULT_ADDR          — Vault API URL
#   VAULT_ROLE_ID       — AppRole role ID (akash-runtime)
#   VAULT_SECRET_ID     — AppRole secret ID (single-use in production)
#
# Optional:
#   VAULT_SECRET_PATHS  — Space-separated KV v2 paths (default: runtime + rpc + agents)
#   VAULT_SKIP_VERIFY   — Set to "true" for dev TLS only
set -euo pipefail

VAULT_SECRET_PATHS="${VAULT_SECRET_PATHS:-yieldswarm/akash/runtime yieldswarm/rpc/solana yieldswarm/rpc/failover yieldswarm/agents/shared}"

log() {
  echo "[vault-fetch] $*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

: "${VAULT_ADDR:?VAULT_ADDR is required}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID is required}"
: "${VAULT_SECRET_ID:?VAULT_SECRET_ID is required}"

CURL_OPTS=(--fail --silent --show-error --max-time 30)
if [[ "${VAULT_SKIP_VERIFY:-false}" == "true" ]]; then
  CURL_OPTS+=(--insecure)
fi

log "Authenticating to Vault via AppRole..."
AUTH_RESPONSE=$(curl "${CURL_OPTS[@]}" \
  --request POST \
  --header "Content-Type: application/json" \
  --data "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"${VAULT_SECRET_ID}\"}" \
  "${VAULT_ADDR}/v1/auth/approle/login") || die "AppRole login failed"

VAULT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token // empty')
[[ -n "$VAULT_TOKEN" ]] || die "No client_token in AppRole response"

# Unset secret ID immediately after use (single-use in production)
unset VAULT_SECRET_ID

fetch_secret() {
  local path="$1"
  local response
  response=$(curl "${CURL_OPTS[@]}" \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/secret/data/${path}") || die "Failed to read secret/${path}"

  echo "$response" | jq -r '
    .data.data
    | to_entries[]
    | select(.key | startswith("_") | not)
    | "\(.key | ascii_upcase)=\(.value | @sh)"
  '
}

SECRETS_FILE="${SECRETS_FILE:-/run/yieldswarm/secrets.env}"
mkdir -p "$(dirname "$SECRETS_FILE")"
: > "$SECRETS_FILE"
chmod 600 "$SECRETS_FILE"

for path in $VAULT_SECRET_PATHS; do
  log "Fetching secret/${path}..."
  fetch_secret "$path" >> "$SECRETS_FILE"
done

# Export into current shell environment for child processes
set -a
# shellcheck disable=SC1090
source "$SECRETS_FILE"
set +a

log "Secrets loaded into ${SECRETS_FILE} ($(wc -l < "$SECRETS_FILE") keys)"

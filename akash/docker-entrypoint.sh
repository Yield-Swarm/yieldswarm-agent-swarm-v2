#!/usr/bin/env bash
# Fetch secrets from HashiCorp Vault at container start and export as env vars.
# Requires VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID (AppRole — not provider API keys).
# Never logs secret values.

set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR is required}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID is required}"
: "${VAULT_SECRET_ID:?VAULT_SECRET_ID is required}"

VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-yieldswarm}"
VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-false}"
export VAULT_ADDR

if [[ "${VAULT_SKIP_VERIFY}" == "true" ]]; then
  export VAULT_SKIP_VERIFY=true
fi

log() {
  printf '[entrypoint] %s\n' "$*" >&2
}

vault_login() {
  local token
  token="$(
    vault write -field=token auth/approle/login \
      role_id="${VAULT_ROLE_ID}" \
      secret_id="${VAULT_SECRET_ID}"
  )"
  export VAULT_TOKEN="${token}"
}

# Read a KV v2 secret path and export each key as an uppercase env var.
# Optional prefix avoids collisions (e.g. AZURE_TENANT_ID).
load_secret() {
  local path="$1"
  local prefix="${2:-}"

  log "Loading secret path: ${VAULT_KV_MOUNT}/${path}"

  local json
  json="$(vault kv get -format=json "${VAULT_KV_MOUNT}/${path}")"
  local data
  data="$(echo "${json}" | jq -c '.data.data')"

  local keys
  keys="$(echo "${data}" | jq -r 'keys[]')"

  local key value env_name
  while IFS= read -r key; do
    [[ -z "${key}" ]] && continue
    value="$(echo "${data}" | jq -r --arg k "${key}" '.[$k]')"
    if [[ -n "${prefix}" ]]; then
      env_name="$(printf '%s_%s' "${prefix}" "${key}" | tr '[:lower:]' '[:upper:]')"
    else
      env_name="$(printf '%s' "${key}" | tr '[:lower:]' '[:upper:]')"
    fi
    export "${env_name}=${value}"
  done <<< "${keys}"
}

log "Authenticating to Vault via AppRole..."
vault_login

load_secret "azure" "AZURE"
load_secret "runpod" "RUNPOD"
load_secret "vultr" "VULTR"
load_secret "digitalocean" "DIGITALOCEAN"
load_secret "rpc" ""
load_secret "agents" ""

# Map Vault rpc keys to application env names from .env.example
export SOLANA_RPC_URL="${SOLANA_RPC_URL:-}"
export HELIUS_API_KEY="${HELIUS_API_KEY:-}"
export FAILOVER_RPC_LIST="${FAILOVER_RPC_LIST:-}"

# Map agent secrets
export GROK_API_KEY="${GROK_API_KEY:-}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export AGENTSWARM_MASTER_KEY="${AGENTSWARM_MASTER_KEY:-}"

# Provider-specific aliases for downstream agents
export RUNPOD_API_KEY="${RUNPOD_API_KEY:-}"
export VULTR_API_KEY="${VULTR_API_KEY:-}"
export DIGITALOCEAN_TOKEN="${DIGITALOCEAN_TOKEN:-}"

# Unset Vault token before handing off to application process
unset VAULT_TOKEN VAULT_SECRET_ID

log "Secrets loaded. Starting: $*"
exec "$@"

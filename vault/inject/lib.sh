#!/usr/bin/env bash
# vault/inject/lib.sh — shared helpers for dynamic secret injection

set -Eeuo pipefail

VAULT_ADDR="${VAULT_ADDR:-}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
VAULT_ROLE_ID="${VAULT_ROLE_ID:-}"
VAULT_SECRET_ID="${VAULT_SECRET_ID:-}"
KV_MOUNT="${KV_MOUNT:-yieldswarm}"
OUTPUT_FILE="${AGENT_ENV_FILE:-/run/secrets/agent.env}"

log() { printf '[vault-inject] %s\n' "$*" >&2; }

vault_login() {
  if [[ -n "${VAULT_TOKEN}" ]]; then
    return 0
  fi
  : "${VAULT_ADDR:?VAULT_ADDR required}"
  : "${VAULT_ROLE_ID:?VAULT_ROLE_ID required}"
  : "${VAULT_SECRET_ID:?VAULT_SECRET_ID required}"
  VAULT_TOKEN="$(
    curl -sfS -X POST \
      "${VAULT_ADDR}/v1/auth/approle/login" \
      -H 'Content-Type: application/json' \
      -d "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"${VAULT_SECRET_ID}\"}" \
    | jq -r '.auth.client_token'
  )"
  export VAULT_TOKEN
}

kv_export() {
  local path="$1"
  local url="${VAULT_ADDR}/v1/${KV_MOUNT}/data/${path}"
  curl -sfS -H "X-Vault-Token: ${VAULT_TOKEN}" "${url}" \
    | jq -r '.data.data | to_entries[] | "\(.key | ascii_upcase)=\(.value | @sh)"' \
    | sed "s/^'//;s/'$//"
}

render_template() {
  local template="$1"
  local output="${2:-${OUTPUT_FILE}}"
  mkdir -p "$(dirname "${output}")"
  if command -v vault >/dev/null 2>&1 && [[ -n "${VAULT_ADDR}" ]]; then
    vault_login
    vault agent -config="${template}" 2>/dev/null || true
  fi
  if [[ -f "${output}" ]]; then
    log "rendered ${output}"
    return 0
  fi
  log "fallback: env-only injection to ${output}"
  : > "${output}"
}

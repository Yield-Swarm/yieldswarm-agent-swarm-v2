#!/usr/bin/env bash
# vault/setup/lib.sh
# Shared helpers sourced by every setup script.
# All functions are idempotent and safe to re-run.
set -euo pipefail

# ---- Required env -------------------------------------------------------
: "${VAULT_ADDR:?VAULT_ADDR must be set (e.g. https://vault.yieldswarm.io:8200)}"
export VAULT_ADDR

# VAULT_TOKEN is only required for non-init steps; init.sh checks itself.
require_token() {
  : "${VAULT_TOKEN:?VAULT_TOKEN must be set (use root for bootstrap, then revoke)}"
}

# ---- Logging ------------------------------------------------------------
log()  { printf '\033[1;34m[vault-setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[vault-setup]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[vault-setup]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- Wrappers -----------------------------------------------------------
vault_status_ok() {
  vault status -format=json >/dev/null 2>&1
}

wait_for_vault() {
  log "Waiting for Vault at ${VAULT_ADDR} ..."
  for i in $(seq 1 60); do
    if curl -sf --max-time 2 "${VAULT_ADDR}/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200" >/dev/null; then
      log "Vault is responding."
      return 0
    fi
    sleep 2
  done
  die "Vault did not respond at ${VAULT_ADDR} after 120s"
}

is_sealed() {
  vault status -format=json | jq -er '.sealed' >/dev/null 2>&1 && \
    [ "$(vault status -format=json | jq -r '.sealed')" = "true" ]
}

is_initialized() {
  vault status -format=json | jq -er '.initialized' >/dev/null 2>&1 && \
    [ "$(vault status -format=json | jq -r '.initialized')" = "true" ]
}

# Enable a secrets engine only if it isn't already mounted at $path.
ensure_engine() {
  local type="$1" path="$2" extra="${3:-}"
  if vault secrets list -format=json | jq -er --arg p "${path}/" '.[$p]' >/dev/null 2>&1; then
    log "Secrets engine ${type} already mounted at ${path}/ - skipping"
    return 0
  fi
  log "Enabling ${type} engine at ${path}/"
  # shellcheck disable=SC2086
  vault secrets enable -path="${path}" ${extra} "${type}"
}

# Enable an auth method only if not already enabled at $path.
ensure_auth() {
  local type="$1" path="${2:-$1}"
  if vault auth list -format=json | jq -er --arg p "${path}/" '.[$p]' >/dev/null 2>&1; then
    log "Auth method ${type} already enabled at ${path}/ - skipping"
    return 0
  fi
  log "Enabling auth method ${type} at ${path}/"
  vault auth enable -path="${path}" "${type}"
}

# Write a policy from a file, idempotent (Vault `policy write` is upsert).
ensure_policy() {
  local name="$1" file="$2"
  [ -r "$file" ] || die "policy file not found: $file"
  log "Writing policy ${name} from ${file}"
  vault policy write "${name}" "${file}"
}

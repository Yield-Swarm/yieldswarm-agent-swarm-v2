#!/usr/bin/env bash
# 20-enable-engines.sh
# Enable secrets engines + audit device.  Idempotent.

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
vault_check
require_env VAULT_TOKEN

enable_mount() {
  local type="$1" path="$2"; shift 2
  if vault secrets list -format=json | jq -e --arg p "${path}/" 'has($p)' >/dev/null; then
    log "secrets engine already mounted: $path ($type)"
  else
    log "enabling secrets engine: $path ($type)"
    vault secrets enable -path="$path" "$@" "$type"
  fi
}

enable_auth() {
  local type="$1" path="${2:-$1}"
  if vault auth list -format=json | jq -e --arg p "${path}/" 'has($p)' >/dev/null; then
    log "auth method already enabled: $path ($type)"
  else
    log "enabling auth method: $path ($type)"
    vault auth enable -path="$path" "$type"
  fi
}

enable_audit() {
  local type="$1" path="$2"; shift 2
  if vault audit list -format=json | jq -e --arg p "${path}/" 'has($p)' >/dev/null; then
    log "audit device already enabled: $path ($type)"
  else
    log "enabling audit device: $path ($type)"
    vault audit enable -path="$path" "$type" "$@"
  fi
}

# --- KV v2 ---
enable_mount kv "$KV_MOUNT" -version=2 -description="YieldSwarm KV v2 store"

# --- Transit (encryption-as-a-service) ---
enable_mount transit "$TRANSIT_MOUNT" -description="YieldSwarm transit / EaaS"

for k in wallet-encryption db-encryption tf-outputs; do
  if vault read -format=json "${TRANSIT_MOUNT}/keys/$k" >/dev/null 2>&1; then
    log "transit key exists: $k"
  else
    log "creating transit key: $k (aes256-gcm96)"
    vault write -f "${TRANSIT_MOUNT}/keys/$k" type=aes256-gcm96 derived=false
  fi
done

if vault read -format=json "${TRANSIT_MOUNT}/keys/tee-signing" >/dev/null 2>&1; then
  log "transit key exists: tee-signing"
else
  log "creating transit key: tee-signing (ed25519)"
  vault write -f "${TRANSIT_MOUNT}/keys/tee-signing" type=ed25519 derived=false
fi

# --- Auth methods ---
enable_auth approle
enable_auth jwt
enable_auth oidc

# --- Audit ---
audit_path="${VAULT_AUDIT_PATH:-/var/log/vault/audit.log}"
install -d -m 0750 "$(dirname "$audit_path")" || true
enable_audit file file_audit file_path="$audit_path" log_raw=false hmac_accessor=true

log "engines + audit ready"

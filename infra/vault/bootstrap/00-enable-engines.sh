#!/usr/bin/env bash
# Enable the secret engines the APN platform depends on.
#
# Run once per Vault cluster, with a token that holds the apn-admin
# policy (or the root token during the initial cluster bring-up).
#
# Requires: VAULT_ADDR, VAULT_TOKEN exported in the environment.

set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

log() { printf '[bootstrap] %s\n' "$*"; }

enable_if_missing() {
  local type="$1" path="$2"; shift 2
  if vault secrets list -format=json | jq -e --arg p "${path}/" 'has($p)' >/dev/null; then
    log "secrets engine ${type} already mounted at ${path}/, skipping"
  else
    log "enabling ${type} at ${path}/"
    vault secrets enable -path="${path}" "$@" "${type}"
  fi
}

enable_auth_if_missing() {
  local type="$1" path="$2"
  if vault auth list -format=json | jq -e --arg p "${path}/" 'has($p)' >/dev/null; then
    log "auth method ${type} already mounted at ${path}/, skipping"
  else
    log "enabling auth method ${type} at ${path}/"
    vault auth enable -path="${path}" "${type}"
  fi
}

# KV v2 for all human-managed secrets (provider creds, LLM keys, RPC, ...).
enable_if_missing kv kv -version=2

# Transit for envelope encryption + TEE signing. Keys never leave Vault.
enable_if_missing transit transit

# AppRole for machine identities (Terraform, Akash workloads).
enable_auth_if_missing approle approle

# Audit log to disk (rotated by the host's logrotate). Critical for
# tracing which AppRole read which secret and when.
if vault audit list -format=json 2>/dev/null | jq -e 'has("file/")' >/dev/null; then
  log "file audit device already enabled"
else
  log "enabling file audit device at /var/log/vault/audit.log"
  vault audit enable file file_path=/var/log/vault/audit.log
fi

log "secret engines and auth methods are ready"

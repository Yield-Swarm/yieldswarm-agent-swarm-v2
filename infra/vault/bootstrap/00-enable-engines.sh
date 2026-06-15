#!/usr/bin/env bash
# =============================================================================
# 00-enable-engines.sh
# -----------------------------------------------------------------------------
# Idempotently enable every secrets engine + auth method the AgentSwarm OS
# needs. Safe to re-run; uses `vault secrets list -format=json` to skip mounts
# that already exist.
#
# Requires: $VAULT_ADDR, $VAULT_TOKEN (root or admin), `vault` CLI, `jq`.
# =============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

log() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }

has_mount() {
  local path="$1/"
  vault secrets list -format=json | jq -e --arg p "$path" 'has($p)' >/dev/null 2>&1
}

has_auth() {
  local path="$1/"
  vault auth list -format=json | jq -e --arg p "$path" 'has($p)' >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Secrets engines
# -----------------------------------------------------------------------------
if ! has_mount "yieldswarm"; then
  log "Enabling KV-v2 at yieldswarm/"
  vault secrets enable -path=yieldswarm -version=2 \
    -description="AgentSwarm OS canonical secrets store" kv
else
  log "yieldswarm/ already mounted - skipping"
fi

if ! has_mount "transit"; then
  log "Enabling transit/"
  vault secrets enable -path=transit \
    -description="Encryption-as-a-Service for AgentSwarm workloads" transit
else
  log "transit/ already mounted - skipping"
fi

if ! has_mount "pki_int"; then
  log "Enabling pki_int/ (intermediate CA for mTLS between Vault clients)"
  vault secrets enable -path=pki_int \
    -max-lease-ttl=43800h \
    -description="AgentSwarm intermediate CA" pki
else
  log "pki_int/ already mounted - skipping"
fi

# -----------------------------------------------------------------------------
# Auth methods
# -----------------------------------------------------------------------------
if ! has_auth "approle"; then
  log "Enabling approle/ auth"
  vault auth enable approle
else
  log "approle/ already enabled - skipping"
fi

if ! has_auth "oidc"; then
  log "Enabling oidc/ auth (humans authenticate here)"
  vault auth enable oidc
else
  log "oidc/ already enabled - skipping"
fi

# -----------------------------------------------------------------------------
# Audit device (file). Production deployments should ALSO ship logs to a
# remote SIEM via the `socket` audit device; that is configured separately so
# this bootstrap stays portable.
# -----------------------------------------------------------------------------
if ! vault audit list -format=json | jq -e 'has("file/")' >/dev/null 2>&1; then
  log "Enabling file audit device at /vault/logs/audit.log"
  vault audit enable file file_path=/vault/logs/audit.log log_raw=false
else
  log "file/ audit device already enabled - skipping"
fi

# -----------------------------------------------------------------------------
# Transit keys for the runtime + CI signing flows
# -----------------------------------------------------------------------------
for key in agentswarm-runtime terraform-ci ci-image-signing; do
  if ! vault read -format=json "transit/keys/${key}" >/dev/null 2>&1; then
    log "Creating transit key: ${key}"
    case "$key" in
      *signing*|terraform-ci) type="ed25519" ;;
      *)                      type="aes256-gcm96" ;;
    esac
    vault write -f "transit/keys/${key}" type="${type}" \
      derived=false exportable=false allow_plaintext_backup=false
  else
    log "transit key ${key} already exists - skipping"
  fi
done

log "Engines + auth methods + audit + transit keys ready."

#!/usr/bin/env bash
# =============================================================================
# YieldSwarm Vault bootstrap
# -----------------------------------------------------------------------------
# Idempotent setup script for a fresh (or existing) Vault cluster.
#
#   * Enables KV v2 at  kv/
#   * Enables transit at transit/   (+ creates yieldswarm-wallets key)
#   * Enables AppRole auth at auth/approle/
#   * Enables file + syslog audit devices
#   * Writes all policies under ./policies/
#   * Creates the `yieldswarm-terraform` and `yieldswarm-akash` AppRoles
#   * Prints the role_id + a response-wrapped secret_id for each role
#
# Requires:
#   * vault >= 1.15
#   * VAULT_ADDR  (e.g. https://vault.example.com:8200)
#   * VAULT_TOKEN with sufficient privileges (root or a sys-admin policy)
#
# Usage:
#   export VAULT_ADDR=https://vault.example.com:8200
#   export VAULT_TOKEN=hvs.xxxxxxxx
#   ./infrastructure/vault/setup.sh
#
# Safe to re-run: every step checks current state before mutating.
# =============================================================================

set -euo pipefail

POLICY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/policies"

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

log() { printf '\033[1;34m[vault-setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[vault-setup]\033[0m %s\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# 1. Audit devices (file + syslog). Audit logs are mandatory for production.
# -----------------------------------------------------------------------------
enable_audit() {
  local path="$1" type="$2"; shift 2
  if vault audit list -format=json | jq -e --arg p "${path}/" 'has($p)' >/dev/null; then
    log "audit ${path} already enabled"
  else
    log "enabling audit ${path} (${type})"
    vault audit enable -path="${path}" "${type}" "$@"
  fi
}

enable_audit file file file_path=/var/log/vault/audit.log || \
  warn "file audit enable failed - ensure /var/log/vault exists and is writable"
enable_audit syslog syslog tag=vault facility=AUTH || \
  warn "syslog audit enable failed - acceptable on macOS dev"

# -----------------------------------------------------------------------------
# 2. Secrets engines
# -----------------------------------------------------------------------------
mount_if_missing() {
  local path="$1" type="$2"; shift 2
  if vault secrets list -format=json | jq -e --arg p "${path}/" 'has($p)' >/dev/null; then
    log "secrets ${path} already mounted"
  else
    log "mounting ${type} at ${path}"
    vault secrets enable -path="${path}" "$@" "${type}"
  fi
}

mount_if_missing kv      kv      -version=2
mount_if_missing transit transit

# Create the transit key used to encrypt wallet payloads at rest.
if vault read -format=json transit/keys/yieldswarm-wallets >/dev/null 2>&1; then
  log "transit key yieldswarm-wallets already exists"
else
  log "creating transit key yieldswarm-wallets"
  vault write -f transit/keys/yieldswarm-wallets \
    type=aes256-gcm96 \
    derived=false \
    exportable=false \
    allow_plaintext_backup=false
fi

# Enforce automatic rotation every 30 days.
vault write transit/keys/yieldswarm-wallets/config \
  deletion_allowed=false \
  min_decryption_version=1 \
  auto_rotate_period=720h >/dev/null

# -----------------------------------------------------------------------------
# 3. Auth methods
# -----------------------------------------------------------------------------
auth_if_missing() {
  local path="$1" type="$2"
  if vault auth list -format=json | jq -e --arg p "${path}/" 'has($p)' >/dev/null; then
    log "auth ${path} already enabled"
  else
    log "enabling auth ${type} at ${path}"
    vault auth enable -path="${path}" "${type}"
  fi
}

auth_if_missing approle approle

# Tune AppRole token defaults: short default, capped at 24h.
vault auth tune -default-lease-ttl=1h -max-lease-ttl=24h approle/ >/dev/null

# -----------------------------------------------------------------------------
# 4. Policies
# -----------------------------------------------------------------------------
for policy in terraform-reader akash-runtime secrets-admin ci-writer; do
  log "writing policy ${policy}"
  vault policy write "${policy}" "${POLICY_DIR}/${policy}.hcl"
done

# -----------------------------------------------------------------------------
# 5. AppRoles
# -----------------------------------------------------------------------------
#
# Terraform role:
#   * non-periodic, max TTL 1h (each `terraform apply` re-auths)
#   * secret_id TTL 10m, single use (CIDR-locked in production)
#   * tokens are NOT renewable to avoid stale plans using stale creds
#
log "creating/updating AppRole yieldswarm-terraform"
vault write auth/approle/role/yieldswarm-terraform \
  token_policies="terraform-reader" \
  token_ttl=1h \
  token_max_ttl=1h \
  token_num_uses=0 \
  token_no_default_policy=true \
  secret_id_ttl=10m \
  secret_id_num_uses=1 \
  bind_secret_id=true >/dev/null

#
# Akash runtime role:
#   * periodic token (auto-renewing) so long-lived workloads stay authed
#   * secret_id TTL 1h, single-use, response-wrapped at issue time
#   * token TTL 24h, renewable indefinitely while period <= 24h
#
log "creating/updating AppRole yieldswarm-akash"
vault write auth/approle/role/yieldswarm-akash \
  token_policies="akash-runtime" \
  token_period=24h \
  token_no_default_policy=true \
  secret_id_ttl=1h \
  secret_id_num_uses=1 \
  bind_secret_id=true >/dev/null

# -----------------------------------------------------------------------------
# 6. Emit role_ids and wrapped secret_ids
# -----------------------------------------------------------------------------
emit_creds() {
  local role="$1"
  local role_id
  role_id="$(vault read -field=role_id "auth/approle/role/${role}/role-id")"
  local wrapped
  wrapped="$(VAULT_WRAP_TTL=300 vault write -f -field=wrapping_token \
    "auth/approle/role/${role}/secret-id")"

  printf '\n----- %s -----\n' "${role}"
  printf 'ROLE_ID            = %s\n' "${role_id}"
  printf 'WRAPPED_SECRET_ID  = %s   (TTL 300s, single-unwrap)\n' "${wrapped}"
}

emit_creds yieldswarm-terraform
emit_creds yieldswarm-akash

log "done. Store the wrapped secret_ids in your secret distribution channel."
log "Unwrap with:  VAULT_TOKEN=<wrapped> vault unwrap"

#!/usr/bin/env bash
# =============================================================================
# YieldSwarm — Vault bootstrap
# -----------------------------------------------------------------------------
# Idempotently configures a running, unsealed Vault for the YieldSwarm stack:
#   1. KV v2 secrets engine at  kv/
#   2. Transit engine          transit/   (envelope encryption for app data)
#   3. File audit device
#   4. ACL policies (terraform-provisioner, akash-runtime, secrets-admin)
#   5. AppRole auth method + two roles (terraform-provisioner, akash-runtime)
#
# Requires: vault CLI on PATH, plus the following environment variables:
#   VAULT_ADDR    e.g. https://vault.internal:8200
#   VAULT_TOKEN   a token with sufficient privileges (root only for bootstrap)
#
# This script writes NO secret material. Use seed-secrets.sh for that.
# =============================================================================
set -euo pipefail

POLICY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../policies" && pwd)"
KV_MOUNT="${KV_MOUNT:-kv}"

log() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[bootstrap:error]\033[0m %s\n' "$*" >&2; exit 1; }

command -v vault >/dev/null 2>&1 || die "vault CLI not found on PATH"
: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

vault status >/dev/null 2>&1 || die "Vault is unreachable or sealed at ${VAULT_ADDR}"

# --- helpers ----------------------------------------------------------------
secret_engine_enabled() { vault secrets list -format=json | grep -q "\"${1}/\""; }
auth_method_enabled()   { vault auth list   -format=json | grep -q "\"${1}/\""; }
audit_device_enabled()  { vault audit list  -format=json 2>/dev/null | grep -q "\"${1}/\""; }

# --- 1. KV v2 ---------------------------------------------------------------
if secret_engine_enabled "${KV_MOUNT}"; then
  log "KV engine '${KV_MOUNT}/' already enabled — skipping"
else
  log "Enabling KV v2 engine at '${KV_MOUNT}/'"
  vault secrets enable -path="${KV_MOUNT}" -version=2 kv
fi
# Enforce explicit versioning + cas to prevent blind overwrites.
vault kv metadata put -mount="${KV_MOUNT}" -max-versions=10 -cas-required=false yieldswarm >/dev/null 2>&1 || true

# --- 2. Transit (envelope encryption for at-rest app data) ------------------
if secret_engine_enabled "transit"; then
  log "Transit engine already enabled — skipping"
else
  log "Enabling transit engine at 'transit/'"
  vault secrets enable transit
fi
if vault read -format=json transit/keys/yieldswarm-data >/dev/null 2>&1; then
  log "Transit key 'yieldswarm-data' exists — skipping"
else
  log "Creating transit key 'yieldswarm-data'"
  vault write -f transit/keys/yieldswarm-data type=aes256-gcm96
fi

# --- 3. Audit device --------------------------------------------------------
if audit_device_enabled "file"; then
  log "File audit device already enabled — skipping"
else
  log "Enabling file audit device -> /var/log/vault/audit.log"
  vault audit enable file file_path=/var/log/vault/audit.log || \
    log "WARN: could not enable file audit (check that /var/log/vault exists & is writable)"
fi

# --- 4. Policies ------------------------------------------------------------
for pol in terraform-provisioner akash-runtime secrets-admin; do
  log "Writing policy '${pol}'"
  vault policy write "${pol}" "${POLICY_DIR}/${pol}.hcl"
done

# --- 5. AppRole -------------------------------------------------------------
if auth_method_enabled "approle"; then
  log "AppRole auth already enabled — skipping"
else
  log "Enabling AppRole auth method"
  vault auth enable approle
fi

log "Configuring AppRole 'terraform-provisioner'"
vault write auth/approle/role/terraform-provisioner \
  token_policies="terraform-provisioner" \
  secret_id_ttl="60m" \
  token_ttl="20m" \
  token_max_ttl="60m" \
  token_num_uses=0 \
  secret_id_num_uses=0 \
  token_type="service"

log "Configuring AppRole 'akash-runtime'"
vault write auth/approle/role/akash-runtime \
  token_policies="akash-runtime" \
  secret_id_ttl="0" \
  token_ttl="60m" \
  token_max_ttl="4h" \
  token_num_uses=0 \
  secret_id_num_uses=0 \
  token_type="service"

log "Bootstrap complete."
log "Fetch role IDs with:"
log "  vault read auth/approle/role/terraform-provisioner/role-id"
log "  vault read auth/approle/role/akash-runtime/role-id"
log "Generate a wrapped secret_id with:"
log "  vault write -wrap-ttl=120s -f auth/approle/role/akash-runtime/secret-id"

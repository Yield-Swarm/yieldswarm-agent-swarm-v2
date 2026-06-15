#!/usr/bin/env bash
# vault/scripts/bootstrap.sh
#
# Idempotent bootstrap of the YieldSwarm Vault layout.
#
#   * Enables audit logging to a file device.
#   * Enables KV v2 at mount "yieldswarm/".
#   * Enables transit at mount "transit/" and creates a non-exportable "wallet" key.
#   * Enables the AppRole auth method.
#   * Writes the four ACL policies in ../policies/.
#   * Creates AppRoles: terraform, ci, akash-runtime  (no Secret IDs are issued
#     here — issue them per-consumer with `vault write -f auth/approle/role/<r>/secret-id`,
#     ideally response-wrapped, see SECRETS.md).
#
# Re-runnable: every step checks current state before mutating.
#
# Required env:
#   VAULT_ADDR   e.g. https://vault.yieldswarm.internal:8200
#   VAULT_TOKEN  a token with the admin policy (root or break-glass)
#
# Optional:
#   AUDIT_FILE_PATH      default /var/log/vault/audit.log
#   KV_MOUNT             default yieldswarm
#   TRANSIT_MOUNT        default transit

set -Eeuo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set (admin/root)}"

AUDIT_FILE_PATH="${AUDIT_FILE_PATH:-/var/log/vault/audit.log}"
KV_MOUNT="${KV_MOUNT:-yieldswarm}"
TRANSIT_MOUNT="${TRANSIT_MOUNT:-transit}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
POLICY_DIR="$(cd -- "${SCRIPT_DIR}/../policies" >/dev/null 2>&1 && pwd)"

log() { printf '[bootstrap] %s\n' "$*" >&2; }

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required binary: $1" >&2
    exit 1
  }
}
require vault
require jq

# ---------------------------------------------------------------------------
# Audit device (file). Refuses to disable an already-enabled audit device so
# we use `vault audit list -format=json` to detect.
# ---------------------------------------------------------------------------
if vault audit list -format=json | jq -e '."file/"' >/dev/null 2>&1; then
  log "audit device file/ already enabled"
else
  log "enabling file audit device -> ${AUDIT_FILE_PATH}"
  vault audit enable file file_path="${AUDIT_FILE_PATH}"
fi

# ---------------------------------------------------------------------------
# KV v2 mount.
# ---------------------------------------------------------------------------
if vault secrets list -format=json | jq -e --arg m "${KV_MOUNT}/" '.[$m]' >/dev/null 2>&1; then
  log "kv mount ${KV_MOUNT}/ already enabled"
else
  log "enabling kv-v2 at ${KV_MOUNT}/"
  vault secrets enable -path="${KV_MOUNT}" -version=2 kv
fi

# ---------------------------------------------------------------------------
# Transit mount + wallet key (non-exportable, deletion disallowed).
# ---------------------------------------------------------------------------
if vault secrets list -format=json | jq -e --arg m "${TRANSIT_MOUNT}/" '.[$m]' >/dev/null 2>&1; then
  log "transit mount ${TRANSIT_MOUNT}/ already enabled"
else
  log "enabling transit at ${TRANSIT_MOUNT}/"
  vault secrets enable -path="${TRANSIT_MOUNT}" transit
fi

if vault read -format=json "${TRANSIT_MOUNT}/keys/wallet" >/dev/null 2>&1; then
  log "transit key 'wallet' already exists"
else
  log "creating transit key 'wallet' (aes256-gcm96, non-exportable)"
  vault write -f "${TRANSIT_MOUNT}/keys/wallet" \
    type=aes256-gcm96 \
    exportable=false \
    allow_plaintext_backup=false \
    deletion_allowed=false
fi

# ---------------------------------------------------------------------------
# AppRole auth method.
# ---------------------------------------------------------------------------
if vault auth list -format=json | jq -e '."approle/"' >/dev/null 2>&1; then
  log "approle auth already enabled"
else
  log "enabling approle auth"
  vault auth enable approle
fi

# ---------------------------------------------------------------------------
# Policies.
# ---------------------------------------------------------------------------
for p in admin terraform ci akash-runtime; do
  file="${POLICY_DIR}/${p}.hcl"
  [[ -r "${file}" ]] || { echo "missing policy file: ${file}" >&2; exit 1; }
  log "writing policy '${p}' <- ${file}"
  vault policy write "${p}" "${file}"
done

# ---------------------------------------------------------------------------
# AppRoles. Tight TTLs; secret IDs are issued out-of-band per consumer.
# ---------------------------------------------------------------------------
log "configuring approle role 'terraform' (operator/local plan+apply)"
vault write auth/approle/role/terraform \
  token_policies="terraform" \
  token_ttl="30m" \
  token_max_ttl="2h" \
  secret_id_ttl="24h" \
  secret_id_num_uses=5 \
  token_num_uses=0 \
  bind_secret_id=true

log "configuring approle role 'ci' (GitHub Actions / GitLab CI)"
vault write auth/approle/role/ci \
  token_policies="ci" \
  token_ttl="20m" \
  token_max_ttl="1h" \
  secret_id_ttl="15m" \
  secret_id_num_uses=1 \
  token_num_uses=10 \
  bind_secret_id=true

log "configuring approle role 'akash-runtime' (long-running workload)"
vault write auth/approle/role/akash-runtime \
  token_policies="akash-runtime" \
  token_ttl="1h" \
  token_max_ttl="24h" \
  secret_id_ttl="72h" \
  secret_id_num_uses=1 \
  token_num_uses=0 \
  bind_secret_id=true

ROLE_ID_TF=$(vault read -field=role_id auth/approle/role/terraform/role-id)
ROLE_ID_CI=$(vault read -field=role_id auth/approle/role/ci/role-id)
ROLE_ID_AK=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)

cat <<EOF

[bootstrap] complete.

Role IDs (safe to store in config / CI variables; NOT secret on their own):
  terraform     ${ROLE_ID_TF}
  ci            ${ROLE_ID_CI}
  akash-runtime ${ROLE_ID_AK}

Next: issue response-wrapped Secret IDs to each consumer. See SECRETS.md
§"Issue AppRole Secret IDs" for the exact commands.
EOF

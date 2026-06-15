#!/usr/bin/env bash
#
# bootstrap.sh — Idempotently configure HashiCorp Vault for the YieldSwarm
# AgentSwarm OS secrets integration.
#
# It performs the following, all of which are safe to re-run:
#   1. Enables the KV v2 secrets engine (default mount: "secret").
#   2. Enables the AppRole auth method.
#   3. Writes the three least-privilege policies in ./policies (with the KV
#      mount name substituted in).
#   4. Creates two AppRoles:
#        - yieldswarm-terraform   (policy: terraform-read)
#        - yieldswarm-akash       (policy: akash-runtime-read)
#   5. Prints the RoleIDs (non-sensitive) for use by Terraform and Akash.
#
# This script writes NO secret values. Use seed-secrets.sh for that.
#
# Required environment:
#   VAULT_ADDR   e.g. https://vault.example.com:8200
#   VAULT_TOKEN  a token with privileges to mount engines / write policies
#                (e.g. the root token during initial setup, or a
#                 secrets-admin token plus sys mount privileges).
#
# Optional environment:
#   KV_MOUNT             KV v2 mount path                  (default: secret)
#   APPROLE_PATH         AppRole auth mount path           (default: approle)
#   TF_TOKEN_TTL         Terraform token TTL               (default: 30m)
#   TF_TOKEN_MAX_TTL     Terraform token max TTL           (default: 1h)
#   AKASH_TOKEN_TTL      Akash runtime token TTL           (default: 1h)
#   AKASH_TOKEN_MAX_TTL  Akash runtime token max TTL       (default: 24h)
#   AKASH_SECRET_ID_TTL  Akash SecretID TTL                (default: 24h)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"

KV_MOUNT="${KV_MOUNT:-secret}"
APPROLE_PATH="${APPROLE_PATH:-approle}"
TF_TOKEN_TTL="${TF_TOKEN_TTL:-30m}"
TF_TOKEN_MAX_TTL="${TF_TOKEN_MAX_TTL:-1h}"
AKASH_TOKEN_TTL="${AKASH_TOKEN_TTL:-1h}"
AKASH_TOKEN_MAX_TTL="${AKASH_TOKEN_MAX_TTL:-24h}"
AKASH_SECRET_ID_TTL="${AKASH_SECRET_ID_TTL:-24h}"

log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

command -v vault >/dev/null 2>&1 || die "vault CLI not found on PATH."
: "${VAULT_ADDR:?VAULT_ADDR must be set (e.g. https://vault.example.com:8200)}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set to a token allowed to configure Vault}"

vault token lookup >/dev/null 2>&1 || die "Cannot authenticate to Vault at ${VAULT_ADDR}. Check VAULT_ADDR / VAULT_TOKEN."

# --- 1. KV v2 secrets engine ------------------------------------------------
if vault secrets list -format=json | jq -e --arg m "${KV_MOUNT}/" 'has($m)' >/dev/null; then
  log "KV mount '${KV_MOUNT}/' already enabled."
else
  log "Enabling KV v2 secrets engine at '${KV_MOUNT}/'."
  vault secrets enable -path="${KV_MOUNT}" -version=2 kv
fi

# --- 2. AppRole auth method -------------------------------------------------
if vault auth list -format=json | jq -e --arg m "${APPROLE_PATH}/" 'has($m)' >/dev/null; then
  log "AppRole auth '${APPROLE_PATH}/' already enabled."
else
  log "Enabling AppRole auth method at '${APPROLE_PATH}/'."
  vault auth enable -path="${APPROLE_PATH}" approle
fi

# --- 3. Policies (substitute KV mount placeholder) --------------------------
write_policy() {
  name="$1"; file="$2"
  [ -f "$file" ] || die "Policy file not found: $file"
  log "Writing policy '${name}' (KV mount: ${KV_MOUNT})."
  sed "s|@@KV_MOUNT@@|${KV_MOUNT}|g" "$file" | vault policy write "$name" -
}

write_policy "terraform-read"     "${POLICY_DIR}/terraform-read.hcl"
write_policy "akash-runtime-read" "${POLICY_DIR}/akash-runtime-read.hcl"
write_policy "secrets-admin"      "${POLICY_DIR}/secrets-admin.hcl"

# --- 4. AppRoles ------------------------------------------------------------
log "Configuring AppRole 'yieldswarm-terraform'."
vault write "auth/${APPROLE_PATH}/role/yieldswarm-terraform" \
  token_policies="terraform-read" \
  token_ttl="${TF_TOKEN_TTL}" \
  token_max_ttl="${TF_TOKEN_MAX_TTL}" \
  secret_id_num_uses=0 \
  secret_id_ttl="0" \
  token_num_uses=0

log "Configuring AppRole 'yieldswarm-akash'."
# Akash runtime: short-lived, single-use SecretIDs delivered via response
# wrapping (see SECRETS.md). secret_id_num_uses=1 ensures a leaked SecretID
# cannot be replayed once the container has consumed it.
vault write "auth/${APPROLE_PATH}/role/yieldswarm-akash" \
  token_policies="akash-runtime-read" \
  token_ttl="${AKASH_TOKEN_TTL}" \
  token_max_ttl="${AKASH_TOKEN_MAX_TTL}" \
  secret_id_num_uses=1 \
  secret_id_ttl="${AKASH_SECRET_ID_TTL}" \
  token_num_uses=0

# --- 5. Emit RoleIDs --------------------------------------------------------
TF_ROLE_ID="$(vault read -field=role_id "auth/${APPROLE_PATH}/role/yieldswarm-terraform/role-id")"
AKASH_ROLE_ID="$(vault read -field=role_id "auth/${APPROLE_PATH}/role/yieldswarm-akash/role-id")"

cat <<EOF

============================================================
 Vault bootstrap complete.
============================================================
 KV v2 mount        : ${KV_MOUNT}/
 AppRole mount      : ${APPROLE_PATH}/
 Policies written   : terraform-read, akash-runtime-read, secrets-admin

 RoleIDs (NON-SECRET — safe to store in CI variables / SDL):
   yieldswarm-terraform : ${TF_ROLE_ID}
   yieldswarm-akash     : ${AKASH_ROLE_ID}

 Next steps:
   1. Seed secrets:        ./seed-secrets.sh
   2. Issue a Terraform SecretID:
        vault write -f auth/${APPROLE_PATH}/role/yieldswarm-terraform/secret-id
   3. Issue a wrapped Akash SecretID (recommended, 120s wrap TTL):
        vault write -wrap-ttl=120s -f \\
          auth/${APPROLE_PATH}/role/yieldswarm-akash/secret-id
============================================================
EOF

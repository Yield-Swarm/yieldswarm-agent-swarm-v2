#!/usr/bin/env bash
# terraform/scripts/vault-login.sh
#
# Convenience login helper used by humans and CI to swap a wrapped
# SecretID for a short-lived Vault token before running `terraform`.
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.io:8200
#   export VAULT_ROLE_ID=<role_id from vault/terraform-vault-config output>
#   export VAULT_WRAPPED_SECRET_ID=<one-shot wrapped token, e.g. from `vault write -wrap-ttl=300s -f auth/approle/role/terraform/secret-id`>
#   source ./terraform/scripts/vault-login.sh
#   terraform plan
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR is required}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID is required}"
: "${VAULT_WRAPPED_SECRET_ID:?VAULT_WRAPPED_SECRET_ID is required}"

# 1. Unwrap the SecretID (consumes the wrap token, one-shot)
SECRET_ID="$(VAULT_TOKEN="${VAULT_WRAPPED_SECRET_ID}" vault unwrap -format=json | jq -r '.data.secret_id')"
[ -n "${SECRET_ID}" ] || { echo "unwrap returned empty SecretID" >&2; exit 1; }

# 2. Exchange RoleID + SecretID for an actual Vault token
VAULT_TOKEN="$(vault write -format=json auth/approle/login \
  role_id="${VAULT_ROLE_ID}" \
  secret_id="${SECRET_ID}" | jq -r '.auth.client_token')"

unset SECRET_ID VAULT_WRAPPED_SECRET_ID
export VAULT_TOKEN
echo "VAULT_TOKEN exported (ttl: $(vault token lookup -format=json | jq -r '.data.ttl')s)"

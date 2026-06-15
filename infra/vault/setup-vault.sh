#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

KV_MOUNT="${KV_MOUNT:-kv}"

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI is required" >&2
  exit 1
fi

if ! vault secrets list | rg -q "^${KV_MOUNT}/"; then
  vault secrets enable -path="${KV_MOUNT}" -version=2 kv
fi

if ! vault auth list | rg -q "^approle/"; then
  vault auth enable approle
fi

vault policy write terraform-read "${SCRIPT_DIR}/policies/terraform-read.hcl"
vault policy write akash-runtime "${SCRIPT_DIR}/policies/akash-runtime.hcl"

vault write auth/approle/role/terraform-reader \
  token_policies="terraform-read" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  secret_id_ttl="24h" \
  secret_id_num_uses="50"

vault write auth/approle/role/akash-runtime \
  token_policies="akash-runtime" \
  token_ttl="30m" \
  token_max_ttl="2h" \
  secret_id_ttl="24h" \
  secret_id_num_uses="200"

echo "Vault bootstrap complete."
echo "Terraform AppRole role_id:"
vault read -field=role_id auth/approle/role/terraform-reader/role-id
echo "Akash AppRole role_id:"
vault read -field=role_id auth/approle/role/akash-runtime/role-id
echo "Generate Secret IDs with:"
echo "  vault write -f -field=secret_id auth/approle/role/terraform-reader/secret-id"
echo "  vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id"

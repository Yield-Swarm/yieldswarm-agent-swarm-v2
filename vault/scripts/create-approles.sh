#!/usr/bin/env bash
# Create AppRoles for Terraform and Akash workloads.
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

echo "==> Enabling AppRole auth method"
if ! vault auth list -format=json | jq -e '.["approle/"]' >/dev/null 2>&1; then
  vault auth enable approle
else
  echo "    approle/ already enabled"
fi

echo "==> Creating terraform AppRole"
vault write auth/approle/role/terraform \
  token_policies="terraform" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  secret_id_ttl="0" \
  secret_id_num_uses="0"

echo "==> Creating akash-runtime AppRole"
vault write auth/approle/role/akash-runtime \
  token_policies="akash-runtime" \
  token_ttl="30m" \
  token_max_ttl="2h" \
  secret_id_ttl="24h" \
  secret_id_num_uses="1" \
  bind_secret_id="true"

echo "==> Creating akash-deploy AppRole"
vault write auth/approle/role/akash-deploy \
  token_policies="akash-deploy" \
  token_ttl="15m" \
  token_max_ttl="1h" \
  secret_id_ttl="1h" \
  secret_id_num_uses="5" \
  bind_secret_id="true"

echo ""
echo "==> AppRole role IDs (store securely):"
echo "terraform:     $(vault read -field=role_id auth/approle/role/terraform/role-id)"
echo "akash-runtime: $(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
echo "akash-deploy:  $(vault read -field=role_id auth/approle/role/akash-deploy/role-id)"
echo ""
echo "Generate secret IDs with:"
echo "  vault write -f auth/approle/role/terraform/secret-id"
echo "  vault write -f auth/approle/role/akash-runtime/secret-id"
echo "  vault write -f auth/approle/role/akash-deploy/secret-id"

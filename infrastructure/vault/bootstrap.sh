#!/usr/bin/env bash
set -euo pipefail

for required_bin in vault jq; do
  if ! command -v "${required_bin}" >/dev/null 2>&1; then
    echo "Missing dependency: ${required_bin}" >&2
    exit 1
  fi
done

: "${VAULT_ADDR:?Set VAULT_ADDR before running this script}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN before running this script}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${ROOT_DIR}/policies"

ensure_kv_v2_mount() {
  local mount_path="$1"

  if vault secrets list -format=json | jq -e --arg mount "${mount_path}/" 'has($mount)' >/dev/null; then
    echo "Secrets engine already enabled at ${mount_path}/"
  else
    vault secrets enable -path="${mount_path}" kv-v2
    echo "Enabled kv-v2 at ${mount_path}/"
  fi
}

ensure_approle_auth() {
  if vault auth list -format=json | jq -e 'has("approle/")' >/dev/null; then
    echo "AppRole auth backend already enabled"
  else
    vault auth enable approle
    echo "Enabled AppRole auth backend"
  fi
}

ensure_kv_v2_mount "kv-infra"
ensure_kv_v2_mount "kv-runtime"
ensure_approle_auth

vault policy write terraform-read "${POLICY_DIR}/terraform-read.hcl"
vault policy write akash-runtime "${POLICY_DIR}/akash-runtime.hcl"

vault write auth/approle/role/terraform-ci \
  token_policies="terraform-read" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  secret_id_ttl="24h" \
  secret_id_num_uses="0"

vault write auth/approle/role/akash-runtime \
  token_policies="akash-runtime" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  secret_id_ttl="24h" \
  secret_id_num_uses="1"

terraform_role_id="$(vault read -field=role_id auth/approle/role/terraform-ci/role-id)"
akash_role_id="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"

echo
echo "Bootstrap complete."
echo "terraform-ci role_id: ${terraform_role_id}"
echo "akash-runtime role_id: ${akash_role_id}"
echo
echo "Create short-lived secret IDs when needed:"
echo "  vault write -f -field=secret_id auth/approle/role/terraform-ci/secret-id"
echo "  vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id"

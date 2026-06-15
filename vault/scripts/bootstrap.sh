#!/usr/bin/env bash
# Bootstrap YieldSwarm Vault: KV engine, policies, AppRoles, and secret path scaffolding.
# Run once against an initialized, unsealed Vault with a bootstrap token.
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.internal:8200
#   export VAULT_TOKEN=<bootstrap-token>
#   ./vault/scripts/bootstrap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$(cd "${SCRIPT_DIR}/../policies" && pwd)"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

log() { printf '[bootstrap] %s\n' "$*"; }

log "Verifying Vault connectivity..."
vault status >/dev/null

log "Enabling KV v2 secrets engine at yieldswarm/..."
if vault secrets list -format=json | jq -e '.["yieldswarm/"]' >/dev/null 2>&1; then
  log "  yieldswarm/ already enabled"
else
  vault secrets enable -path=yieldswarm kv-v2
fi

log "Writing ACL policies..."
vault policy write yieldswarm-admin "${POLICY_DIR}/admin.hcl"
vault policy write yieldswarm-terraform-read "${POLICY_DIR}/terraform-read.hcl"
vault policy write yieldswarm-akash-runtime "${POLICY_DIR}/akash-runtime.hcl"

log "Enabling AppRole auth..."
if vault auth list -format=json | jq -e '.["approle/"]' >/dev/null 2>&1; then
  log "  approle already enabled"
else
  vault auth enable approle
fi

log "Configuring AppRole: yieldswarm-terraform..."
vault write auth/approle/role/yieldswarm-terraform \
  token_policies="yieldswarm-terraform-read" \
  token_ttl="20m" \
  token_max_ttl="1h" \
  secret_id_ttl="0" \
  secret_id_num_uses="0"

log "Configuring AppRole: yieldswarm-akash-runtime..."
vault write auth/approle/role/yieldswarm-akash-runtime \
  token_policies="yieldswarm-akash-runtime" \
  token_ttl="15m" \
  token_max_ttl="30m" \
  secret_id_ttl="0" \
  secret_id_num_uses="0"

log "Scaffolding empty secret paths (placeholder values — replace before production)..."
PLACEHOLDER='REPLACE_ME_BEFORE_PRODUCTION'

vault kv put yieldswarm/azure \
  tenant_id="${PLACEHOLDER}" \
  subscription_id="${PLACEHOLDER}" \
  client_id="${PLACEHOLDER}" \
  client_secret="${PLACEHOLDER}" \
  resource_group="${PLACEHOLDER}" \
  location="eastus"

vault kv put yieldswarm/runpod \
  api_key="${PLACEHOLDER}"

vault kv put yieldswarm/vultr \
  api_key="${PLACEHOLDER}"

vault kv put yieldswarm/digitalocean \
  token="${PLACEHOLDER}" \
  spaces_access_key="${PLACEHOLDER}" \
  spaces_secret_key="${PLACEHOLDER}"

vault kv put yieldswarm/rpc \
  solana_rpc_url="https://api.mainnet-beta.solana.com" \
  helius_api_key="${PLACEHOLDER}" \
  failover_rpc_list='["https://api.mainnet-beta.solana.com"]'

vault kv put yieldswarm/agents \
  grok_api_key="${PLACEHOLDER}" \
  openai_api_key="${PLACEHOLDER}" \
  agentswarm_master_key="${PLACEHOLDER}"

log "Emitting AppRole credentials (store in CI/CD and Akash SDL env securely)..."
TF_ROLE_ID="$(vault read -field=role_id auth/approle/role/yieldswarm-terraform/role-id)"
TF_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/yieldswarm-terraform/secret-id)"
AKASH_ROLE_ID="$(vault read -field=role_id auth/approle/role/yieldswarm-akash-runtime/role-id)"
AKASH_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/yieldswarm-akash-runtime/secret-id)"

cat <<EOF

Bootstrap complete.

Terraform AppRole:
  VAULT_ROLE_ID=${TF_ROLE_ID}
  VAULT_SECRET_ID=${TF_SECRET_ID}

Akash runtime AppRole:
  VAULT_ROLE_ID=${AKASH_ROLE_ID}
  VAULT_SECRET_ID=${AKASH_SECRET_ID}

Next steps:
  1. Replace placeholder secret values (see SECRETS.md).
  2. Enable audit logging: vault audit enable file file_path=/vault/audit/audit.log
  3. Revoke the bootstrap root token.
  4. Wire AppRole credentials into Terraform Cloud / GitHub Actions and Akash SDL.

EOF

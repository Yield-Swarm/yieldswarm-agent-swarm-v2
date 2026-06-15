#!/usr/bin/env bash
# Bootstrap YieldSwarm Vault: KV v2 engine, policies, AppRoles, and secret scaffolding.
# Run once after `vault operator init` and unseal.
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.internal:8200
#   export VAULT_TOKEN=<root-or-admin-token>
#   ./infra/vault/scripts/bootstrap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$(cd "${SCRIPT_DIR}/../policies" && pwd)"

: "${VAULT_ADDR:?Set VAULT_ADDR to your Vault API endpoint}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN to an admin token}"

log() { printf '[vault-bootstrap] %s\n' "$*"; }

require_vault() {
  if ! command -v vault >/dev/null 2>&1; then
    echo "vault CLI not found. Install: https://developer.hashicorp.com/vault/install" >&2
    exit 1
  fi
  vault status >/dev/null
}

enable_kv() {
  if vault secrets list -format=json | jq -e 'has("yieldswarm/")' >/dev/null; then
    log "KV v2 engine already mounted at yieldswarm/"
  else
    log "Mounting KV v2 secrets engine at yieldswarm/"
    vault secrets enable -path=yieldswarm kv-v2
  fi
}

write_policy() {
  local name="$1"
  local file="$2"
  log "Writing policy: ${name}"
  vault policy write "${name}" "${file}"
}

enable_approle() {
  if vault auth list -format=json | jq -e 'has("approle/")' >/dev/null; then
    log "AppRole auth already enabled"
  else
    log "Enabling AppRole auth"
    vault auth enable approle
  fi
}

configure_approle() {
  local role="$1"
  local policy="$2"
  local ttl="${3:-1h}"
  local max_ttl="${4:-4h}"

  log "Configuring AppRole: ${role}"
  vault write "auth/approle/role/${role}" \
    token_policies="${policy}" \
    token_ttl="${ttl}" \
    token_max_ttl="${max_ttl}" \
    secret_id_ttl="24h" \
    secret_id_num_uses=0 \
    token_num_uses=0
}

seed_secret_if_missing() {
  local path="$1"
  shift
  if vault kv get -format=json "yieldswarm/${path}" >/dev/null 2>&1; then
    log "Secret already exists: yieldswarm/${path} (skipping)"
  else
    log "Seeding placeholder secret: yieldswarm/${path}"
    vault kv put "yieldswarm/${path}" "$@"
  fi
}

require_vault
enable_kv

write_policy "yieldswarm-admin" "${POLICY_DIR}/admin-policy.hcl"
write_policy "yieldswarm-terraform" "${POLICY_DIR}/terraform-policy.hcl"
write_policy "yieldswarm-akash-runtime" "${POLICY_DIR}/akash-runtime-policy.hcl"
write_policy "yieldswarm-ci-readonly" "${POLICY_DIR}/ci-readonly-policy.hcl"

enable_approle
configure_approle "terraform" "yieldswarm-terraform" "1h" "4h"
configure_approle "akash-runtime" "yieldswarm-akash-runtime" "30m" "2h"
configure_approle "ci-readonly" "yieldswarm-ci-readonly" "15m" "1h"

# --- Secret scaffolding (replace placeholders before production use) ---
seed_secret_if_missing "azure" \
  subscription_id="REPLACE_ME" \
  tenant_id="REPLACE_ME" \
  client_id="REPLACE_ME" \
  client_secret="REPLACE_ME" \
  resource_group="yieldswarm-prod" \
  location="eastus2"

seed_secret_if_missing "runpod" \
  api_key="REPLACE_ME" \
  default_gpu_type="NVIDIA RTX 4090" \
  default_region="US"

seed_secret_if_missing "vultr" \
  api_key="REPLACE_ME" \
  default_region="ewr"

seed_secret_if_missing "digitalocean" \
  api_token="REPLACE_ME" \
  default_region="nyc3" \
  spaces_access_key="REPLACE_ME" \
  spaces_secret_key="REPLACE_ME"

seed_secret_if_missing "rpc" \
  solana_rpc_url="https://api.mainnet-beta.solana.com" \
  helius_api_key="REPLACE_ME" \
  failover_rpc_list='["https://rpc1.example.com","https://rpc2.example.com"]' \
  birdeye_api_key="REPLACE_ME" \
  jupiter_api_key="REPLACE_ME"

seed_secret_if_missing "akash" \
  auth_method="jwt" \
  key_name="yieldswarm-admin" \
  keyring_backend="test" \
  wallet_mnemonic="REPLACE_ME" \
  account_address="REPLACE_ME" \
  provider_jwt="" \
  console_api_key="" \
  certificate_path="/secrets/akash/cert.pem" \
  key_path="/secrets/akash/key.pem" \
  rpc_endpoint="https://rpc.akt.dev/rpc" \
  chain_id="akashnet-2" \
  gas_prices="0.025uakt" \
  agentswarm_master_key="REPLACE_ME" \
  gpu_cluster_keys='["REPLACE_ME"]'

seed_secret_if_missing "kairo" \
  api_signing_key="REPLACE_ME" \
  bridge_webhook_secret="REPLACE_ME" \
  wise_payout_email="" \
  depin_helium_webhook="" \
  depin_grass_webhook=""

log "Bootstrap complete."
log ""
log "Next steps:"
log "  1. Replace all REPLACE_ME values — see SECRETS.md"
log "  2. Generate AppRole credentials:"
log "       vault read auth/approle/role/terraform/role-id"
log "       vault write -f auth/approle/role/terraform/secret-id"
log "       vault read auth/approle/role/akash-runtime/role-id"
log "       vault write -f auth/approle/role/akash-runtime/secret-id"
log "  3. Store role-id/secret-id in your CI/CD secret store (never in git)"

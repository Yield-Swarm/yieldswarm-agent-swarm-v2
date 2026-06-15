#!/usr/bin/env bash
# vault/setup.sh
# One-time Vault initialization for YieldSwarm AgentSwarm OS v2.
#
# Prerequisites:
#   - Vault server running and unsealed (VAULT_ADDR set, VAULT_TOKEN = root token)
#   - vault CLI on PATH
#   - jq on PATH
#
# Usage:
#   export VAULT_ADDR="https://vault.yieldswarm.io:8200"
#   export VAULT_TOKEN="<root-or-admin-token>"
#   bash vault/setup.sh
#
# After this script completes, follow the "Store your secrets" section in SECRETS.md.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[vault-setup]${NC} $*"; }
ok()   { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
fail() { echo -e "${RED}[ FAIL ]${NC} $*"; exit 1; }

# ---------------------------------------------------------------------------
# 0. Pre-flight checks
# ---------------------------------------------------------------------------
for cmd in vault jq; do
  command -v "$cmd" &>/dev/null || fail "'$cmd' is not on PATH. Install it first."
done

[[ -z "${VAULT_ADDR:-}" ]]  && fail "VAULT_ADDR is not set."
[[ -z "${VAULT_TOKEN:-}" ]] && fail "VAULT_TOKEN is not set."

log "Checking Vault connectivity at ${VAULT_ADDR}..."
vault status -format=json | jq -e '.sealed == false' > /dev/null \
  || fail "Vault is sealed or unreachable. Unseal it first."
ok "Vault is reachable and unsealed."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Enable KV v2 secrets engine at "secret/"
# ---------------------------------------------------------------------------
log "Enabling KV v2 secrets engine at 'secret/'..."
if vault secrets list -format=json | jq -e '."secret/" != null' > /dev/null 2>&1; then
  warn "'secret/' engine already mounted — skipping."
else
  vault secrets enable -path=secret -version=2 kv
  ok "KV v2 enabled at 'secret/'."
fi

# ---------------------------------------------------------------------------
# 2. Apply policies
# ---------------------------------------------------------------------------
log "Writing Vault policies..."

for policy in admin terraform akash-agent; do
  policy_file="${SCRIPT_DIR}/policies/${policy}.hcl"
  [[ -f "$policy_file" ]] || fail "Policy file not found: ${policy_file}"
  vault policy write "$policy" "$policy_file"
  ok "Policy '${policy}' applied."
done

# ---------------------------------------------------------------------------
# 3. Enable AppRole auth method
# ---------------------------------------------------------------------------
log "Enabling AppRole auth method..."
if vault auth list -format=json | jq -e '."approle/" != null' > /dev/null 2>&1; then
  warn "AppRole auth already enabled — skipping."
else
  vault auth enable approle
  ok "AppRole auth enabled."
fi

# ---------------------------------------------------------------------------
# 4. Create AppRole for Terraform (long-lived CI token, no secret_id wrapping)
# ---------------------------------------------------------------------------
log "Creating 'terraform' AppRole role..."
vault write auth/approle/role/terraform \
  token_policies="terraform" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  token_num_uses=0 \
  secret_id_ttl="0" \
  bind_secret_id=true
ok "AppRole role 'terraform' created."

TERRAFORM_ROLE_ID=$(vault read -field=role_id auth/approle/role/terraform/role-id)
TERRAFORM_SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/terraform/secret-id)

# ---------------------------------------------------------------------------
# 5. Create AppRole for Akash Agent (single-use, wrapped secret IDs)
# ---------------------------------------------------------------------------
log "Creating 'akash-agent' AppRole role..."
vault write auth/approle/role/akash-agent \
  token_policies="akash-agent" \
  token_ttl="2h" \
  token_max_ttl="8h" \
  token_num_uses=0 \
  secret_id_ttl="24h" \
  bind_secret_id=true
ok "AppRole role 'akash-agent' created."

AKASH_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-agent/role-id)
# Generate a wrapped secret_id (TTL 5 min) — unwrap once during deploy
AKASH_WRAPPED_SECRET_ID=$(vault write -wrap-ttl=300s -field=wrapping_token \
  -f auth/approle/role/akash-agent/secret-id)

# ---------------------------------------------------------------------------
# 6. Scaffold secret paths with placeholder values
#    (Operators must replace these with real values — see SECRETS.md)
# ---------------------------------------------------------------------------
log "Scaffolding secret paths with placeholder values..."

vault kv put secret/azure/credentials \
  subscription_id="REPLACE_ME" \
  client_id="REPLACE_ME" \
  client_secret="REPLACE_ME" \
  tenant_id="REPLACE_ME"
ok "secret/azure/credentials scaffolded."

vault kv put secret/runpod/credentials \
  api_key="REPLACE_ME"
ok "secret/runpod/credentials scaffolded."

vault kv put secret/vultr/credentials \
  api_key="REPLACE_ME"
ok "secret/vultr/credentials scaffolded."

vault kv put secret/digitalocean/credentials \
  token="REPLACE_ME" \
  spaces_access_key="REPLACE_ME" \
  spaces_secret_key="REPLACE_ME"
ok "secret/digitalocean/credentials scaffolded."

vault kv put secret/rpc/solana \
  endpoint="https://api.mainnet-beta.solana.com" \
  helius_api_key="REPLACE_ME" \
  birdeye_api_key="REPLACE_ME" \
  jupiter_api_key="REPLACE_ME" \
  raydium_api_key="REPLACE_ME" \
  pump_fun_deploy_key="REPLACE_ME" \
  solscan_api_key="REPLACE_ME" \
  failover_rpc_list='["REPLACE_ME_RPC1","REPLACE_ME_RPC2"]'
ok "secret/rpc/solana scaffolded."

vault kv put secret/rpc/evm \
  ton_api_key="REPLACE_ME" \
  tao_subnet_key="REPLACE_ME" \
  helix_chain_bridge_key="REPLACE_ME" \
  zec_shielded_key="REPLACE_ME" \
  erc4337_bundler_key="REPLACE_ME"
ok "secret/rpc/evm scaffolded."

vault kv put secret/agents/master \
  agentswarm_master_key="REPLACE_ME" \
  kimiclaw_consensus_key="REPLACE_ME" \
  wallet_encryption_key="REPLACE_ME" \
  tee_signing_key="REPLACE_ME" \
  database_encryption_key="REPLACE_ME" \
  grok_api_key="REPLACE_ME" \
  openai_api_key="REPLACE_ME" \
  gemini_api_key="REPLACE_ME" \
  anthropic_api_key="REPLACE_ME"
ok "secret/agents/master scaffolded."

vault kv put secret/agents/blockchain \
  apn_mint_address="8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump" \
  pump_fun_coin_id="8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump" \
  raydium_pool_id="REPLACE_ME" \
  lp_token_address="REPLACE_ME" \
  ng64_bittensor_node_staking_key="REPLACE_ME" \
  zkml_verifier_key="REPLACE_ME"
ok "secret/agents/blockchain scaffolded."

vault kv put secret/agents/depin \
  depin_helium_hotspot_keys='["REPLACE_ME"]' \
  gpu_cluster_keys='["REPLACE_ME"]' \
  grass_node_keys='["REPLACE_ME"]' \
  smartthings_bridge_token="REPLACE_ME" \
  colorado_power_permit_id="REPLACE_ME" \
  utility_api_key="REPLACE_ME"
ok "secret/agents/depin scaffolded."

vault kv put secret/agents/integrations \
  notion_api_key="REPLACE_ME" \
  linear_api_key="REPLACE_ME" \
  vercel_api_token="REPLACE_ME" \
  github_token="REPLACE_ME" \
  telegram_bot_token="REPLACE_ME" \
  ud_api_key="REPLACE_ME" \
  dexscreener_api="REPLACE_ME" \
  filecoin_storage_key="REPLACE_ME" \
  quarantined_llm_arena_key="REPLACE_ME"
ok "secret/agents/integrations scaffolded."

# ---------------------------------------------------------------------------
# 7. Print credentials summary
# ---------------------------------------------------------------------------
cat <<EOF

${GREEN}═══════════════════════════════════════════════════════════════════${NC}
${GREEN}  Vault Setup Complete — Save These Values Securely!${NC}
${GREEN}═══════════════════════════════════════════════════════════════════${NC}

${YELLOW}Terraform AppRole${NC}
  VAULT_ROLE_ID  = ${TERRAFORM_ROLE_ID}
  VAULT_SECRET_ID = ${TERRAFORM_SECRET_ID}

  → Store in CI/CD secrets (GitHub Actions, etc.) or your local ~/.vault_terraform

${YELLOW}Akash Agent AppRole${NC}
  VAULT_ROLE_ID          = ${AKASH_ROLE_ID}
  VAULT_WRAPPED_TOKEN    = ${AKASH_WRAPPED_SECRET_ID}  ← expires in 5 min, single-use unwrap

  → Unwrap with: vault unwrap <VAULT_WRAPPED_TOKEN>
  → Store the resulting secret_id in your Akash SDL environment block

${YELLOW}Next steps${NC}
  1. Replace all REPLACE_ME values with real secrets (see SECRETS.md §3)
  2. Run: bash terraform/scripts/vault-env.sh   to verify Terraform auth
  3. Run: terraform -chdir=terraform init && terraform plan

${GREEN}═══════════════════════════════════════════════════════════════════${NC}

EOF

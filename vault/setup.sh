#!/usr/bin/env bash
# ============================================================
# YieldSwarm AgentSwarm OS v2.0 — Vault Setup Script
# ============================================================
# Idempotent: safe to re-run; skips steps already completed.
#
# Prerequisites
#   - vault CLI ≥ 1.15 on PATH
#   - VAULT_ADDR exported (e.g. https://vault.yieldswarm.internal:8200)
#   - VAULT_TOKEN exported with admin/root privileges
#   - jq on PATH
#
# Usage
#   export VAULT_ADDR=https://vault.yieldswarm.internal:8200
#   export VAULT_TOKEN=<root-or-admin-token>
#   bash vault/setup.sh
# ============================================================
set -euo pipefail

# ── Colour helpers ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Guards ───────────────────────────────────────────────────
[[ -z "${VAULT_ADDR:-}" ]] && die "VAULT_ADDR is not set"
[[ -z "${VAULT_TOKEN:-}" ]] && die "VAULT_TOKEN is not set"
command -v vault >/dev/null 2>&1 || die "vault CLI not found on PATH"
command -v jq    >/dev/null 2>&1 || die "jq not found on PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"

echo -e "\n${BOLD}YieldSwarm Vault Setup${NC}"
echo "──────────────────────────────────────────"
info "Vault: ${VAULT_ADDR}"

# ── Health check ─────────────────────────────────────────────
STATUS=$(vault status -format=json 2>/dev/null || true)
SEALED=$(echo "${STATUS}" | jq -r '.sealed // "unknown"')
INIT=$(echo "${STATUS}"   | jq -r '.initialized // "false"')

[[ "${INIT}" == "false" ]] && die "Vault is not initialized. Run 'vault operator init' first."
[[ "${SEALED}" == "true" ]] && die "Vault is sealed. Unseal it before running setup."
success "Vault is initialized and unsealed"

# ── 1. Enable KV v2 secrets engine ──────────────────────────
info "Enabling KV v2 secrets engine at 'secret/'"
if vault secrets list -format=json | jq -e '."secret/"' >/dev/null 2>&1; then
  warn "secrets engine 'secret/' already mounted — skipping"
else
  vault secrets enable -path=secret -version=2 kv
  success "Mounted KV v2 at secret/"
fi

# ── 2. Enable audit logging ──────────────────────────────────
info "Enabling file audit log at /opt/vault/logs/audit.log"
if vault audit list -format=json | jq -e '.["file/"]' >/dev/null 2>&1; then
  warn "Audit backend 'file/' already enabled — skipping"
else
  vault audit enable file file_path=/opt/vault/logs/audit.log log_format=json
  success "Audit log enabled"
fi

# ── 3. Write placeholder secret skeleton ────────────────────
# These are PLACEHOLDERS — replace values with real secrets.
# The script only writes a path if it does not already exist
# (version 1 would be missing), preserving any existing data.

write_secret_if_missing() {
  local path="$1"
  shift
  local existing
  existing=$(vault kv get -format=json "secret/${path}" 2>/dev/null | jq -r '.data.data // empty' || true)
  if [[ -n "${existing}" ]]; then
    warn "secret/${path} already exists — skipping initial write"
  else
    vault kv put "secret/${path}" "$@"
    success "Wrote placeholder secret: secret/${path}"
  fi
}

info "Writing secret path skeleton (placeholder values)..."

write_secret_if_missing "yieldswarm/core" \
  master_key="REPLACE_ME" \
  kimiclaw_key="REPLACE_ME" \
  wallet_encryption_key="REPLACE_ME" \
  tee_signing_key="REPLACE_ME" \
  db_encryption_key="REPLACE_ME"

write_secret_if_missing "yieldswarm/llm" \
  grok_api_key="REPLACE_ME" \
  openai_api_key="REPLACE_ME" \
  gemini_api_key="REPLACE_ME" \
  anthropic_api_key="REPLACE_ME"

write_secret_if_missing "yieldswarm/rpc" \
  solana_rpc_url="https://api.mainnet-beta.solana.com" \
  helius_api_key="REPLACE_ME" \
  birdeye_api_key="REPLACE_ME" \
  jupiter_api_key="REPLACE_ME" \
  raydium_api_key="REPLACE_ME" \
  ton_api_key="REPLACE_ME" \
  tao_subnet_key="REPLACE_ME" \
  helix_chain_bridge_key="REPLACE_ME" \
  zec_shielded_key="REPLACE_ME" \
  erc4337_bundler_key="REPLACE_ME" \
  failover_rpc_list='["https://rpc1.example.com","https://rpc2.example.com"]'

write_secret_if_missing "yieldswarm/azure" \
  subscription_id="REPLACE_ME" \
  tenant_id="REPLACE_ME" \
  client_id="REPLACE_ME" \
  client_secret="REPLACE_ME" \
  resource_group="yieldswarm-prod"

write_secret_if_missing "yieldswarm/runpod" \
  api_key="REPLACE_ME" \
  endpoint_url="https://api.runpod.io/graphql"

write_secret_if_missing "yieldswarm/vultr" \
  api_key="REPLACE_ME"

write_secret_if_missing "yieldswarm/do" \
  token="REPLACE_ME" \
  spaces_access_key="REPLACE_ME" \
  spaces_secret_key="REPLACE_ME" \
  region="nyc3"

write_secret_if_missing "yieldswarm/blockchain" \
  pump_fun_deploy_key="REPLACE_ME" \
  apn_mint_address="8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump" \
  raydium_pool_id="REPLACE_ME" \
  lp_token_address="REPLACE_ME"

write_secret_if_missing "yieldswarm/depin" \
  helium_hotspot_keys='["REPLACE_ME"]' \
  gpu_cluster_keys='["REPLACE_ME"]' \
  grass_node_keys='["REPLACE_ME"]' \
  smartthings_bridge_token="REPLACE_ME" \
  utility_api_key="REPLACE_ME"

write_secret_if_missing "yieldswarm/integrations" \
  notion_api_key="REPLACE_ME" \
  linear_api_key="REPLACE_ME" \
  vercel_api_token="REPLACE_ME" \
  github_token="REPLACE_ME" \
  telegram_bot_token="REPLACE_ME" \
  ud_api_key="REPLACE_ME" \
  wise_business_email="REPLACE_ME" \
  meta_ads_token="REPLACE_ME"

write_secret_if_missing "yieldswarm/monitoring" \
  prometheus_url="REPLACE_ME" \
  error_webhook="REPLACE_ME" \
  filecoin_storage_key="REPLACE_ME" \
  zkml_verifier_key="REPLACE_ME" \
  dexscreener_api_key="REPLACE_ME" \
  solscan_api_key="REPLACE_ME" \
  admin_account_segment="REPLACE_ME" \
  quarantined_arena_key="REPLACE_ME"

write_secret_if_missing "yieldswarm/akash" \
  wallet_address="REPLACE_ME" \
  key_name="yieldswarm-deployer" \
  chain_id="akashnet-2" \
  node_rpc="https://rpc.akash.forbole.com:443"

# ── 4. Upload policies ───────────────────────────────────────
info "Uploading Vault ACL policies..."

for policy_file in "${POLICY_DIR}"/*.hcl; do
  policy_name="$(basename "${policy_file}" .hcl)"
  vault policy write "${policy_name}" "${policy_file}"
  success "Policy written: ${policy_name}"
done

# ── 5. Enable AppRole auth method ────────────────────────────
info "Enabling AppRole auth method..."
if vault auth list -format=json | jq -e '."approle/"' >/dev/null 2>&1; then
  warn "AppRole auth already enabled — skipping"
else
  vault auth enable approle
  success "AppRole auth method enabled"
fi

# ── 6. Create AppRole roles ──────────────────────────────────
create_approle() {
  local role_name="$1"
  local policy="$2"
  local token_ttl="${3:-1h}"
  local token_max_ttl="${4:-24h}"
  local secret_id_ttl="${5:-24h}"

  info "Creating AppRole role: ${role_name}"
  vault write "auth/approle/role/${role_name}" \
    token_policies="${policy}" \
    token_ttl="${token_ttl}" \
    token_max_ttl="${token_max_ttl}" \
    token_type="service" \
    secret_id_ttl="${secret_id_ttl}" \
    secret_id_num_uses=0 \
    bind_secret_id=true
  success "AppRole role created: ${role_name}"
}

create_approle "yieldswarm-terraform" "yieldswarm-terraform" "1h"  "4h"   "720h"
create_approle "yieldswarm-agents"    "yieldswarm-agents"    "24h" "168h" "168h"
create_approle "yieldswarm-akash"     "yieldswarm-akash"     "24h" "168h" "168h"

# ── 7. Print role IDs ────────────────────────────────────────
echo ""
echo -e "${BOLD}AppRole Role IDs${NC}"
echo "──────────────────────────────────────────"
for role in yieldswarm-terraform yieldswarm-agents yieldswarm-akash; do
  role_id=$(vault read -field=role_id "auth/approle/role/${role}/role-id")
  echo -e "  ${CYAN}${role}${NC}: ${role_id}"
done

echo ""
echo -e "${BOLD}Next steps${NC}"
echo "──────────────────────────────────────────"
echo "  1. Replace all REPLACE_ME values with real secrets:"
echo "       vault kv patch secret/yieldswarm/azure client_secret=\"<real-value>\""
echo ""
echo "  2. Generate a Secret ID for each workload:"
echo "       vault write -f auth/approle/role/yieldswarm-terraform/secret-id"
echo "       vault write -f auth/approle/role/yieldswarm-akash/secret-id"
echo ""
echo "  3. Store ROLE_ID + SECRET_ID safely:"
echo "       Terraform  → CI/CD secrets (GitHub Actions, etc.)"
echo "       Akash      → Akash SDL environment variables"
echo ""
echo "  4. Run Terraform:"
echo "       cd terraform && terraform init && terraform plan"
echo ""
echo "  5. Build & deploy the Akash image:"
echo "       docker build -t yieldswarm/agentswarm:latest docker/"
echo "       # Deploy via SDL: akash tx deployment create akash/deploy.yaml ..."
echo ""
echo -e "${GREEN}Vault setup complete.${NC}"

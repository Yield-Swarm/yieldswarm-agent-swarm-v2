#!/usr/bin/env bash
# terraform/scripts/vault-env.sh
#
# Pre-Terraform wrapper: authenticates to Vault using AppRole and exports all
# cloud provider credentials as environment variables so Terraform providers
# (azurerm, digitalocean, vultr) pick them up automatically.
#
# Usage — source this script, then run Terraform:
#
#   export VAULT_ADDR="https://vault.yieldswarm.io:8200"
#   export VAULT_ROLE_ID="<terraform-role-id>"
#   export VAULT_SECRET_ID="<terraform-secret-id>"
#   source terraform/scripts/vault-env.sh
#   terraform -chdir=terraform plan
#
# For CI/CD (GitHub Actions example):
#   env:
#     VAULT_ADDR:      ${{ secrets.VAULT_ADDR }}
#     VAULT_ROLE_ID:   ${{ secrets.VAULT_ROLE_ID }}
#     VAULT_SECRET_ID: ${{ secrets.VAULT_SECRET_ID }}
#   run: |
#     source terraform/scripts/vault-env.sh
#     terraform -chdir=terraform init
#     terraform -chdir=terraform apply -auto-approve
#
# SECURITY NOTES:
#   - Never log the contents of this script's exported vars.
#   - In CI, mask VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID as secrets.
#   - The Vault token (VAULT_TOKEN) is ephemeral; it expires per the AppRole TTL.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

_log()  { echo -e "${CYAN}[vault-env]${NC} $*" >&2; }
_ok()   { echo -e "${GREEN}[  OK  ]${NC} $*" >&2; }
_warn() { echo -e "${YELLOW}[ WARN ]${NC} $*" >&2; }
_fail() { echo -e "${RED}[ FAIL ]${NC} $*" >&2; return 1; }

# ---------------------------------------------------------------------------
# 0. Pre-flight
# ---------------------------------------------------------------------------
for cmd in vault jq curl; do
  command -v "$cmd" &>/dev/null || _fail "'$cmd' not found on PATH — install it first."
done

: "${VAULT_ADDR:?'VAULT_ADDR is required'}"
: "${VAULT_ROLE_ID:?'VAULT_ROLE_ID is required'}"
: "${VAULT_SECRET_ID:?'VAULT_SECRET_ID is required'}"

# ---------------------------------------------------------------------------
# 1. AppRole login — obtain a short-lived Vault token
# ---------------------------------------------------------------------------
_log "Authenticating to Vault at ${VAULT_ADDR} via AppRole..."

VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="${VAULT_ROLE_ID}" \
  secret_id="${VAULT_SECRET_ID}" 2>/dev/null) \
  || _fail "AppRole login failed. Check VAULT_ROLE_ID and VAULT_SECRET_ID."

export VAULT_TOKEN
_ok "Vault token obtained (TTL: $(vault token lookup -field=ttl 2>/dev/null || echo 'unknown'))."

# ---------------------------------------------------------------------------
# Helper: fetch a single field from a KV v2 secret
# ---------------------------------------------------------------------------
_kv_field() {
  local path="$1" field="$2"
  vault kv get -field="${field}" "secret/${path}" 2>/dev/null \
    || { _warn "Could not read secret/data/${path}[${field}] — skipping."; echo ""; }
}

# ---------------------------------------------------------------------------
# Helper: fetch all fields from a KV v2 secret as JSON
# ---------------------------------------------------------------------------
_kv_json() {
  local path="$1"
  vault kv get -format=json "secret/${path}" 2>/dev/null \
    | jq -r '.data.data' \
    || { _warn "Could not read secret/data/${path} — skipping."; echo "{}"; }
}

# ---------------------------------------------------------------------------
# 2. Azure credentials → ARM_* env vars (azurerm provider)
# ---------------------------------------------------------------------------
_log "Fetching Azure credentials from Vault..."
AZURE_JSON=$(_kv_json "azure/credentials")

export ARM_SUBSCRIPTION_ID=$(echo "$AZURE_JSON" | jq -r '.subscription_id // ""')
export ARM_CLIENT_ID=$(echo "$AZURE_JSON"       | jq -r '.client_id       // ""')
export ARM_CLIENT_SECRET=$(echo "$AZURE_JSON"   | jq -r '.client_secret   // ""')
export ARM_TENANT_ID=$(echo "$AZURE_JSON"       | jq -r '.tenant_id       // ""')

[[ -n "$ARM_SUBSCRIPTION_ID" && "$ARM_SUBSCRIPTION_ID" != "REPLACE_ME" ]] \
  && _ok "Azure credentials loaded." \
  || _warn "Azure credentials contain placeholder values — update secret/azure/credentials."

# ---------------------------------------------------------------------------
# 3. DigitalOcean token → DIGITALOCEAN_TOKEN (digitalocean provider)
# ---------------------------------------------------------------------------
_log "Fetching DigitalOcean credentials from Vault..."
DO_JSON=$(_kv_json "digitalocean/credentials")

export DIGITALOCEAN_TOKEN=$(echo "$DO_JSON"            | jq -r '.token             // ""')
export SPACES_ACCESS_KEY_ID=$(echo "$DO_JSON"          | jq -r '.spaces_access_key // ""')
export SPACES_SECRET_ACCESS_KEY=$(echo "$DO_JSON"      | jq -r '.spaces_secret_key // ""')

[[ -n "$DIGITALOCEAN_TOKEN" && "$DIGITALOCEAN_TOKEN" != "REPLACE_ME" ]] \
  && _ok "DigitalOcean credentials loaded." \
  || _warn "DigitalOcean credentials contain placeholder values."

# ---------------------------------------------------------------------------
# 4. Vultr API key → VULTR_API_KEY (vultr provider)
# ---------------------------------------------------------------------------
_log "Fetching Vultr credentials from Vault..."
VULTR_JSON=$(_kv_json "vultr/credentials")

export VULTR_API_KEY=$(echo "$VULTR_JSON" | jq -r '.api_key // ""')

[[ -n "$VULTR_API_KEY" && "$VULTR_API_KEY" != "REPLACE_ME" ]] \
  && _ok "Vultr credentials loaded." \
  || _warn "Vultr credentials contain placeholder values."

# ---------------------------------------------------------------------------
# 5. RunPod API key (used by Terraform local-exec; no env var convention)
# ---------------------------------------------------------------------------
_log "Fetching RunPod credentials from Vault..."
RUNPOD_JSON=$(_kv_json "runpod/credentials")

export RUNPOD_API_KEY=$(echo "$RUNPOD_JSON" | jq -r '.api_key // ""')

[[ -n "$RUNPOD_API_KEY" && "$RUNPOD_API_KEY" != "REPLACE_ME" ]] \
  && _ok "RunPod credentials loaded." \
  || _warn "RunPod credentials contain placeholder values."

# ---------------------------------------------------------------------------
# 6. RPC secrets — exported for any local-exec scripts or tests
# ---------------------------------------------------------------------------
_log "Fetching Solana RPC secrets from Vault..."
SOLANA_JSON=$(_kv_json "rpc/solana")

export SOLANA_RPC_URL=$(echo "$SOLANA_JSON"         | jq -r '.endpoint        // "https://api.mainnet-beta.solana.com"')
export HELIUS_API_KEY=$(echo "$SOLANA_JSON"          | jq -r '.helius_api_key  // ""')
export BIRDEYE_API_KEY=$(echo "$SOLANA_JSON"         | jq -r '.birdeye_api_key // ""')
export JUPITER_API_KEY=$(echo "$SOLANA_JSON"         | jq -r '.jupiter_api_key // ""')

_log "Fetching EVM RPC secrets from Vault..."
EVM_JSON=$(_kv_json "rpc/evm")

export TON_API_KEY=$(echo "$EVM_JSON"               | jq -r '.ton_api_key            // ""')
export ERC4337_BUNDLER_KEY=$(echo "$EVM_JSON"       | jq -r '.erc4337_bundler_key    // ""')
export HELIX_CHAIN_BRIDGE_KEY=$(echo "$EVM_JSON"    | jq -r '.helix_chain_bridge_key // ""')

_ok "RPC secrets loaded."

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
cat >&2 <<EOF

${GREEN}vault-env.sh complete.${NC}
Exported credentials for: Azure, DigitalOcean, Vultr, RunPod, Solana RPC, EVM RPC.

Run Terraform now:
  terraform -chdir=terraform init
  terraform -chdir=terraform plan
  terraform -chdir=terraform apply

EOF

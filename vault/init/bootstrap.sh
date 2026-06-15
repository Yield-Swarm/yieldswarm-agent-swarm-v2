#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# vault/init/bootstrap.sh
# YieldSwarm AgentSwarm OS — Vault Bootstrap Script
#
# Run this ONCE after Vault is initialized and unsealed.
# It is safe to re-run; every step is idempotent via "vault * | true" guards.
#
# Prerequisites:
#   - VAULT_ADDR exported (e.g. https://vault.yourdomain.com:8200)
#   - VAULT_TOKEN exported (root token from vault operator init)
#   - vault CLI installed and in PATH
# ---------------------------------------------------------------------------
set -euo pipefail

POLICY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/policies"

log()  { echo "[bootstrap] $*"; }
step() { echo; echo "=== $* ==="; }
ok()   { echo "  [ok] $*"; }

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
step "Checking prerequisites"

if [[ -z "${VAULT_ADDR:-}" ]]; then
  echo "ERROR: VAULT_ADDR is not set." >&2
  exit 1
fi
if [[ -z "${VAULT_TOKEN:-}" ]]; then
  echo "ERROR: VAULT_TOKEN is not set." >&2
  exit 1
fi

vault status > /dev/null 2>&1 || {
  echo "ERROR: Cannot connect to Vault at ${VAULT_ADDR}. Is it unsealed?" >&2
  exit 1
}
ok "Connected to Vault at ${VAULT_ADDR}"

# ---------------------------------------------------------------------------
# Enable KV v2 secrets engine at path "secret/"
# ---------------------------------------------------------------------------
step "Enabling KV v2 secrets engine"

if vault secrets list -format=json | grep -q '"secret/"'; then
  ok "KV engine at 'secret/' already enabled"
else
  vault secrets enable -path=secret -version=2 kv
  ok "KV v2 engine enabled at 'secret/'"
fi

# ---------------------------------------------------------------------------
# Enable AppRole auth method
# ---------------------------------------------------------------------------
step "Enabling AppRole auth method"

if vault auth list -format=json | grep -q '"approle/"'; then
  ok "AppRole already enabled"
else
  vault auth enable approle
  ok "AppRole auth method enabled"
fi

# ---------------------------------------------------------------------------
# Enable file audit log
# ---------------------------------------------------------------------------
step "Enabling audit log"

if vault audit list -format=json | grep -q '"file/"'; then
  ok "File audit already enabled"
else
  vault audit enable file file_path=/vault/logs/audit.log
  ok "Audit log enabled at /vault/logs/audit.log"
fi

# ---------------------------------------------------------------------------
# Write policies
# ---------------------------------------------------------------------------
step "Writing policies"

for policy_file in \
    agentswarm-admin \
    terraform \
    akash-runtime \
    ci-deploy; do
  vault policy write "${policy_file}" "${POLICY_DIR}/${policy_file}.hcl"
  ok "Policy '${policy_file}' written"
done

# ---------------------------------------------------------------------------
# Create AppRole roles
# ---------------------------------------------------------------------------
step "Creating AppRole roles"

# terraform role: short-lived tokens, no IP binding required (CI can be ephemeral)
vault write auth/approle/role/terraform \
  token_policies="terraform" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  token_bound_cidrs="" \
  secret_id_num_uses=0 \
  secret_id_ttl="0" 2>/dev/null || true
ok "AppRole role 'terraform' upserted"

# akash-runtime role: longer-lived tokens for containers, single-use secret IDs
vault write auth/approle/role/akash-runtime \
  token_policies="akash-runtime" \
  token_ttl="12h" \
  token_max_ttl="24h" \
  secret_id_num_uses=1 \
  secret_id_ttl="10m" \
  token_renewable=true 2>/dev/null || true
ok "AppRole role 'akash-runtime' upserted"

# ci-deploy role: very short-lived, single-use secret IDs
vault write auth/approle/role/ci-deploy \
  token_policies="ci-deploy" \
  token_ttl="30m" \
  token_max_ttl="1h" \
  secret_id_num_uses=1 \
  secret_id_ttl="5m" 2>/dev/null || true
ok "AppRole role 'ci-deploy' upserted"

# ---------------------------------------------------------------------------
# Initialize KV paths with empty placeholder secrets
# These exist so list and metadata operations succeed before seeding.
# ---------------------------------------------------------------------------
step "Initialising secret paths (placeholders)"

PLACEHOLDER='{"_placeholder": "replace-with-real-value"}'

kv_init() {
  local path="$1"
  if ! vault kv get "secret/${path}" > /dev/null 2>&1; then
    echo "${PLACEHOLDER}" | vault kv put "secret/${path}" - > /dev/null
    ok "Initialized secret/${path}"
  else
    ok "secret/${path} already exists — skipping"
  fi
}

kv_init "agentswarm/core"
kv_init "agentswarm/llm"
kv_init "agentswarm/rpc"
kv_init "agentswarm/cloud/azure"
kv_init "agentswarm/cloud/runpod"
kv_init "agentswarm/cloud/vultr"
kv_init "agentswarm/cloud/digitalocean"
kv_init "agentswarm/depin"
kv_init "agentswarm/integrations"
kv_init "agentswarm/payments"

# ---------------------------------------------------------------------------
# Print role IDs (safe to share — only half of the credential pair)
# ---------------------------------------------------------------------------
step "AppRole Role IDs (safe to embed in config)"

for role in terraform akash-runtime ci-deploy; do
  ROLE_ID=$(vault read -field=role_id "auth/approle/role/${role}/role-id")
  echo "  ${role}: ${ROLE_ID}"
done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
step "Bootstrap complete"

cat <<'EOF'

Next steps:
  1. Seed real secrets:  vault/init/seed-secrets.sh
  2. Get a wrapped secret_id for Akash:
       vault write -wrap-ttl=10m -f auth/approle/role/akash-runtime/secret-id
  3. Get a wrapped secret_id for Terraform:
       vault write -wrap-ttl=10m -f auth/approle/role/terraform/secret-id
  4. Set VAULT_ROLE_ID and VAULT_SECRET_ID in your Terraform environment.
  5. Set VAULT_ROLE_ID and VAULT_SECRET_ID in the Akash deploy.yaml.

EOF

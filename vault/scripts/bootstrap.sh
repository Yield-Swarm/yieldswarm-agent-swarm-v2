#!/usr/bin/env bash
# Full Vault bootstrap for YieldSwarm AgentSwarm OS.
# Run once after Vault init/unseal with an admin token.
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.internal:8200
#   export VAULT_TOKEN=<root-or-admin-token>
#   ./bootstrap.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== YieldSwarm Vault Bootstrap ==="
echo "VAULT_ADDR=${VAULT_ADDR}"

"${SCRIPT_DIR}/enable-secrets-engines.sh"
"${SCRIPT_DIR}/create-policies.sh"
"${SCRIPT_DIR}/create-approles.sh"
"${SCRIPT_DIR}/seed-secrets.sh"

echo ""
echo "=== Bootstrap complete ==="
echo "Next steps:"
echo "  1. Replace REPLACE_ME values in secret paths"
echo "  2. Store Terraform AppRole role_id in CI/CD (TF_VAR_vault_role_id)"
echo "  3. Generate Akash secret_id: vault write -f auth/approle/role/yieldswarm-akash/secret-id"
echo "  4. Run: ./create-shard-policies.sh 0 119  (optional, for 120 cron shards)"
echo "  5. Revoke bootstrap admin token"

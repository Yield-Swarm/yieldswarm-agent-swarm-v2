#!/usr/bin/env bash
# Master bootstrap — run once on a fresh Vault cluster.
# Usage: export VAULT_ADDR VAULT_TOKEN && ./bootstrap.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo " YieldSwarm Vault Bootstrap"
echo "============================================"

"$SCRIPT_DIR/setup-secrets-engines.sh"
"$SCRIPT_DIR/setup-policies.sh"
"$SCRIPT_DIR/create-approles.sh"

echo ""
echo "Bootstrap complete."
echo "Next steps:"
echo "  1. Run seed-secrets.sh with real values (see SECRETS.md)"
echo "  2. Revoke bootstrap root token"
echo "  3. Configure Terraform with AppRole credentials"
echo "  4. Deploy Akash with runtime AppRole secret-id (single-use)"

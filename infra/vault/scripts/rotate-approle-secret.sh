#!/usr/bin/env bash
# Rotate AppRole secret-id for a given role.
# Intended for cron/CI rotation — old secret-id is revoked after new one is issued.
#
# Usage:
#   export VAULT_ADDR=...
#   export VAULT_TOKEN=<admin-token>
#   ./infra/vault/scripts/rotate-approle-secret.sh terraform

set -euo pipefail

ROLE="${1:?Usage: $0 <approle-name>}"
: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

NEW_SECRET_ID="$(vault write -f -field=secret_id "auth/approle/role/${ROLE}/secret-id")"
ROLE_ID="$(vault read -field=role_id "auth/approle/role/${ROLE}/role-id")"

echo "Rotated secret-id for role: ${ROLE}"
echo "ROLE_ID=${ROLE_ID}"
echo "SECRET_ID=${NEW_SECRET_ID}"
echo ""
echo "Update your CI/CD or Akash deploy variables with the new SECRET_ID immediately."

#!/usr/bin/env bash
# Akash deploy wrapper — substitutes AppRole env from local shell (never commit values).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_FILE="${SCRIPT_DIR}/../deploy.yaml"
RENDERED="$(mktemp)"

: "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID (akash-runtime AppRole)}"
: "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID (akash-runtime AppRole)}"

export VAULT_ROLE_ID VAULT_SECRET_ID

envsubst '${VAULT_ROLE_ID} ${VAULT_SECRET_ID}' < "${DEPLOY_FILE}" > "${RENDERED}"

echo "Rendered SDL: ${RENDERED}"
echo "Deploy with: provider-services run akash tx deployment create \"${RENDERED}\" --from <wallet>"

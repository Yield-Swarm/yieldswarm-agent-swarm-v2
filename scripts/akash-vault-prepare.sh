#!/usr/bin/env bash
# Issue AppRole credentials for Akash SDL deploy.
#
# Usage:
#   eval "$(./scripts/akash-vault-prepare.sh integration-backend)"
#   ./scripts/deploy-backend-akash.sh
#
# Roles: integration-backend | bittensor-runtime | akash-runtime | odysseus-runtime
set -euo pipefail

ROLE="${1:-integration-backend}"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN (admin or ci-bootstrap)}"

case "${ROLE}" in
  integration-backend|bittensor-runtime|akash-runtime|odysseus-runtime) ;;
  *)
    echo "usage: $0 <integration-backend|bittensor-runtime|akash-runtime|odysseus-runtime>" >&2
    exit 2
    ;;
esac

ROLE_ID="$(vault read -field=role_id "auth/approle/role/${ROLE}/role-id")"
SECRET_ID="$(vault write -field=secret_id -f "auth/approle/role/${ROLE}/secret-id")"

printf "export VAULT_ADDR='%s'\n" "${VAULT_ADDR}"
printf "export VAULT_ROLE_ID='%s'\n" "${ROLE_ID}"
printf "export VAULT_SECRET_ID='%s'\n" "${SECRET_ID}"

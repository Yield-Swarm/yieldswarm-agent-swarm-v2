#!/usr/bin/env bash
# Rotate AppRole secret_id for terraform or akash-runtime roles.
#
# Usage:
#   ./vault/scripts/rotate-secret-id.sh terraform
#   ./vault/scripts/rotate-secret-id.sh akash-runtime

set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

ROLE="${1:-}"
case "${ROLE}" in
  terraform)     VAULT_ROLE="yieldswarm-terraform" ;;
  akash-runtime) VAULT_ROLE="yieldswarm-akash-runtime" ;;
  *)
    echo "Usage: $0 {terraform|akash-runtime}" >&2
    exit 1
    ;;
esac

ROLE_ID="$(vault read -field=role_id "auth/approle/role/${VAULT_ROLE}/role-id")"
SECRET_ID="$(vault write -f -field=secret_id "auth/approle/role/${VAULT_ROLE}/secret-id")"

printf 'role_id=%s\nsecret_id=%s\n' "${ROLE_ID}" "${SECRET_ID}"

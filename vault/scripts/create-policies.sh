#!/usr/bin/env bash
# Apply all Vault policies from vault/policies/.
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$(cd "${SCRIPT_DIR}/../policies" && pwd)"

for policy_file in "${POLICY_DIR}"/*.hcl; do
  policy_name="$(basename "${policy_file}" .hcl)"
  vault policy write "${policy_name}" "${policy_file}"
  echo "Applied policy: ${policy_name}"
done

echo "All policies applied"

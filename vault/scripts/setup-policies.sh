#!/usr/bin/env bash
# Apply Vault policies from vault/policies/*.hcl
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$(cd "$SCRIPT_DIR/../policies" && pwd)"

echo "==> Applying policies from $POLICY_DIR"
for policy_file in "$POLICY_DIR"/*.hcl; do
  policy_name="$(basename "$policy_file" .hcl)"
  echo "    Writing policy: $policy_name"
  vault policy write "$policy_name" "$policy_file"
done

echo "==> Policies applied:"
vault policy list

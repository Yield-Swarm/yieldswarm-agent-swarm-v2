#!/usr/bin/env bash
# Create AppRoles for Terraform and Akash deployments.
# Outputs role_id values; secret_id must be distributed via secure channel.
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

create_approle() {
  local name="$1"
  local policy="$2"
  local ttl="${3:-1h}"
  local max_ttl="${4:-4h}"

  vault auth enable approle 2>/dev/null || true

  vault write "auth/approle/role/${name}" \
    token_policies="${policy}" \
    token_ttl="${ttl}" \
    token_max_ttl="${max_ttl}" \
    secret_id_ttl="0" \
    secret_id_num_uses="0" \
    token_no_default_policy=true

  local role_id
  role_id="$(vault read -field=role_id "auth/approle/role/${name}/role-id")"
  echo "AppRole ${name}: role_id=${role_id}"
  echo "  Generate secret_id: vault write -f auth/approle/role/${name}/secret-id"
}

create_approle "yieldswarm-terraform" "terraform-policy" "1h" "4h"
create_approle "yieldswarm-akash" "akash-policy" "30m" "2h"
create_approle "yieldswarm-agent" "agent-read-policy" "30m" "2h"

echo "AppRoles created. Store role_id in CI/CD variables; never commit secret_id."

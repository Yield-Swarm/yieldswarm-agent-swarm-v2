#!/usr/bin/env bash
# Create per-shard AppRoles with isolated policies (0-119).
# Usage: ./create-shard-policies.sh [start_shard] [end_shard]
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

START="${1:-0}"
END="${2:-119}"
MOUNT="yieldswarm"

vault auth enable approle 2>/dev/null || true

for shard in $(seq "${START}" "${END}"); do
  shard_padded=$(printf "%03d" "${shard}")
  policy_name="agent-shard-${shard_padded}-policy"
  role_name="yieldswarm-agent-shard-${shard_padded}"

  cat >"/tmp/${policy_name}.hcl" <<EOF
# Auto-generated shard policy — shard ${shard_padded}
path "${MOUNT}/data/agents/shard/${shard_padded}" {
  capabilities = ["read"]
}

path "${MOUNT}/data/rpc" {
  capabilities = ["read"]
}

path "${MOUNT}/metadata/agents/shard/${shard_padded}" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}
EOF

  vault policy write "${policy_name}" "/tmp/${policy_name}.hcl"
  rm -f "/tmp/${policy_name}.hcl"

  vault write "auth/approle/role/${role_name}" \
    token_policies="${policy_name}" \
    token_ttl="30m" \
    token_max_ttl="2h" \
    secret_id_ttl="0" \
    secret_id_num_uses="0" \
    token_no_default_policy=true

  role_id="$(vault read -field=role_id "auth/approle/role/${role_name}/role-id")"
  echo "Shard ${shard_padded}: role=${role_name} role_id=${role_id}"
done

echo "Created ${END} - ${START} + 1 shard policies and AppRoles"

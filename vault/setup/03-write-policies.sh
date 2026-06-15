#!/usr/bin/env bash
# =============================================================================
# 03-write-policies.sh — Apply all Vault policies
# YieldSwarm AgentSwarm OS v2.0
#
# Idempotent: safe to re-run; existing policies are overwritten with the
# current file contents, allowing policy-as-code updates.
#
# Prerequisites:
#   - VAULT_ADDR and VAULT_TOKEN exported
#   - Run from the repository root (policies at vault/policies/)
# =============================================================================
set -euo pipefail

POLICY_DIR="$(cd "$(dirname "$0")/../policies" && pwd)"

write_policy() {
  local name="$1"
  local file="${POLICY_DIR}/${name}.hcl"
  if [ ! -f "$file" ]; then
    echo "[03] WARNING: policy file not found: ${file}"
    return
  fi
  vault policy write "${name}" "${file}"
  echo "[03] Applied policy: ${name}"
}

echo "[03] Writing policies from ${POLICY_DIR}..."
echo ""

write_policy "admin"
write_policy "terraform"
write_policy "akash-agents"
write_policy "runpod"
write_policy "vultr"
write_policy "digitalocean"
write_policy "rpc-readonly"

echo ""
echo "[03] Listing all policies:"
vault policy list

echo ""
echo "[03] All policies applied. Proceed to 04-configure-auth.sh"

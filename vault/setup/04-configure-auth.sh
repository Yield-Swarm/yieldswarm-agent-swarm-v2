#!/usr/bin/env bash
# =============================================================================
# 04-configure-auth.sh — Configure AppRole authentication
# YieldSwarm AgentSwarm OS v2.0
#
# Creates AppRole roles for each deployment target.
# Token TTLs are intentionally short; Vault Agent handles renewal.
#
# Prerequisites:
#   - VAULT_ADDR and VAULT_TOKEN exported
#   - Policies applied (03-write-policies.sh)
# =============================================================================
set -euo pipefail

create_approle() {
  local role_name="$1"
  local policies="$2"
  local token_ttl="${3:-1h}"
  local token_max_ttl="${4:-24h}"
  local secret_id_ttl="${5:-24h}"
  local secret_id_num_uses="${6:-0}"   # 0 = unlimited; set 1 for one-shot deploys

  vault write "auth/approle/role/${role_name}" \
    policies="${policies}" \
    token_ttl="${token_ttl}" \
    token_max_ttl="${token_max_ttl}" \
    token_type="service" \
    secret_id_ttl="${secret_id_ttl}" \
    secret_id_num_uses="${secret_id_num_uses}"

  echo "[04] Created/updated AppRole: ${role_name}"
  echo "     policies=${policies}"
  echo "     token_ttl=${token_ttl} / max=${token_max_ttl}"
  echo "     secret_id_ttl=${secret_id_ttl} / num_uses=${secret_id_num_uses}"
  echo ""
}

echo "[04] === Configuring AppRole authentication ==="
echo ""

# Terraform CI/CD role — unlimited secret_id reuse within TTL
create_approle "terraform" \
  "terraform,rpc-readonly" \
  "1h" "4h" "8h" "0"

# Akash container agents — single-use secret_id per deployment
create_approle "akash-agents" \
  "akash-agents" \
  "2h" "24h" "30m" "1"

# RunPod GPU cluster workers
create_approle "runpod" \
  "runpod" \
  "2h" "24h" "30m" "1"

# Vultr-hosted services
create_approle "vultr" \
  "vultr" \
  "2h" "24h" "30m" "1"

# DigitalOcean-hosted services
create_approle "digitalocean" \
  "digitalocean" \
  "2h" "24h" "30m" "1"

echo "[04] === Listing AppRole roles ==="
vault list auth/approle/role

echo ""
echo "[04] Auth configuration complete. Proceed to 05-create-role-ids.sh"

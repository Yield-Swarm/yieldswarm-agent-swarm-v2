#!/usr/bin/env bash
# Validate Vault health, policies, AppRoles, and KV paths for Terraform + Akash.
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.internal:8200
#   export VAULT_TOKEN=<admin-or-ci-token>
#   ./vault/scripts/validate-secrets.sh

set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

KV_MOUNT="${KV_MOUNT:-yieldswarm}"

REQUIRED_PATHS=(
  "${KV_MOUNT}/cloud/azure"
  "${KV_MOUNT}/cloud/runpod"
  "${KV_MOUNT}/cloud/vultr"
  "${KV_MOUNT}/cloud/digitalocean"
  "${KV_MOUNT}/rpc/solana"
  "${KV_MOUNT}/rpc/helius"
  "${KV_MOUNT}/rpc/birdeye"
  "${KV_MOUNT}/rpc/jupiter"
  "${KV_MOUNT}/rpc/raydium"
  "${KV_MOUNT}/rpc/ton"
  "${KV_MOUNT}/runtime/akash"
  "${KV_MOUNT}/runtime/core"
  "${KV_MOUNT}/runtime/kairo"
)

REQUIRED_POLICIES=(
  terraform
  akash-runtime
  agent-runtime
  ci
)

REQUIRED_APPROLES=(
  terraform
  akash-runtime
)

fail=0

check_health() {
  if vault status -format=json | jq -e '.sealed == false and .initialized == true' >/dev/null; then
    echo "[ok] Vault initialized and unsealed"
  else
    echo "[FAIL] Vault not ready" >&2
    fail=1
  fi
}

check_secret() {
  local path="$1"
  if vault kv get -format=json "${path}" >/dev/null 2>&1; then
    local placeholders
    placeholders="$(vault kv get -format=json "${path}" | jq -r '.data.data | to_entries[]? | select(.value == "REPLACE_ME" or .value == "changeme-set-via-vault") | .key' || true)"
    if [[ -n "${placeholders}" ]]; then
      echo "[WARN] ${path} has placeholder keys: ${placeholders}"
    else
      echo "[ok] ${path}"
    fi
  else
    echo "[FAIL] missing secret: ${path}" >&2
    fail=1
  fi
}

check_policy() {
  local policy="$1"
  if vault policy read "${policy}" >/dev/null 2>&1; then
    echo "[ok] policy ${policy}"
  else
    echo "[FAIL] missing policy: ${policy}" >&2
    fail=1
  fi
}

check_approle() {
  local role="$1"
  if vault read "auth/approle/role/${role}/role-id" >/dev/null 2>&1; then
    echo "[ok] approle ${role}"
  else
    echo "[FAIL] missing approle: ${role}" >&2
    fail=1
  fi
}

check_health
for p in "${REQUIRED_PATHS[@]}"; do check_secret "${p}"; done
for p in "${REQUIRED_POLICIES[@]}"; do check_policy "${p}"; done
for r in "${REQUIRED_APPROLES[@]}"; do check_approle "${r}"; done

if [[ "${fail}" -ne 0 ]]; then
  echo "Validation failed." >&2
  exit 1
fi

echo "All required Vault resources are present."

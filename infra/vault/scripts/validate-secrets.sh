#!/usr/bin/env bash
# Validate Vault health, policies, and secret paths required by Terraform and Akash.
#
# Usage:
#   export VAULT_ADDR=...
#   export VAULT_TOKEN=<token-with-read-access>
#   ./infra/vault/scripts/validate-secrets.sh

set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

REQUIRED_PATHS=(
  yieldswarm/azure
  yieldswarm/runpod
  yieldswarm/vultr
  yieldswarm/digitalocean
  yieldswarm/rpc
  yieldswarm/akash
)

REQUIRED_POLICIES=(
  yieldswarm-terraform
  yieldswarm-akash-runtime
)

REQUIRED_APPROLES=(
  terraform
  akash-runtime
)

fail=0

check_health() {
  if vault status -format=json | jq -e '.sealed == false and .initialized == true' >/dev/null; then
    echo "[ok] Vault is initialized and unsealed"
  else
    echo "[FAIL] Vault is not ready" >&2
    fail=1
  fi
}

check_secret() {
  local path="$1"
  if vault kv get -format=json "${path}" >/dev/null 2>&1; then
    local placeholders
    placeholders="$(vault kv get -format=json "${path}" | jq -r '.data.data | to_entries[] | select(.value == "REPLACE_ME") | .key' || true)"
    if [[ -n "${placeholders}" ]]; then
      echo "[WARN] ${path} still has REPLACE_ME keys: ${placeholders}"
    else
      echo "[ok] ${path}"
    fi
  else
    echo "[FAIL] Missing secret: ${path}" >&2
    fail=1
  fi
}

check_policy() {
  local policy="$1"
  if vault policy read "${policy}" >/dev/null 2>&1; then
    echo "[ok] policy ${policy}"
  else
    echo "[FAIL] Missing policy: ${policy}" >&2
    fail=1
  fi
}

check_approle() {
  local role="$1"
  if vault read "auth/approle/role/${role}/role-id" >/dev/null 2>&1; then
    echo "[ok] approle ${role}"
  else
    echo "[FAIL] Missing approle: ${role}" >&2
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

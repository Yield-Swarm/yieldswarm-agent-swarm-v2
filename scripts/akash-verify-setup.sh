#!/usr/bin/env bash
# Verify Akash setup before first deployment (run in Codespace).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/akash-env.sh"

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  ok   ${label}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL ${label}"
    FAIL=$((FAIL + 1))
  fi
}

echo "==> Tooling"
check "provider-services" command -v provider-services
check "jq" command -v jq

echo ""
echo "==> Environment"
echo "  AKASH_NODE=${AKASH_NODE}"
echo "  AKASH_CHAIN_ID=${AKASH_CHAIN_ID}"
echo "  AKASH_KEY_NAME=${AKASH_KEY_NAME}"
echo "  AKASH_KEYRING_BACKEND=${AKASH_KEYRING_BACKEND}"
echo "  AKASH_AUTH_METHOD=${AKASH_AUTH_METHOD:-keyring}"

if command -v provider-services >/dev/null 2>&1; then
  echo ""
  echo "==> Wallet"
  ADDR="$(provider-services keys show "${AKASH_KEY_NAME}" -a \
    --keyring-backend "${AKASH_KEYRING_BACKEND}" 2>/dev/null || true)"
  if [[ -n "${ADDR}" ]]; then
    echo "  ok   key '${AKASH_KEY_NAME}' -> ${ADDR}"
    PASS=$((PASS + 1))
    BAL="$(provider-services query bank balances "${ADDR}" --node "${AKASH_NODE}" -o json 2>/dev/null \
      | jq -r '.balances[]? | select(.denom=="uakt") | .amount' || echo "0")"
    echo "  balance: ${BAL:-0} uakt"
    if [[ "${BAL:-0}" -gt 1000000 ]]; then
      echo "  ok   funded (>${BAL} uakt)"
      PASS=$((PASS + 1))
    else
      echo "  WARN low balance — fund wallet before deploy"
    fi
  else
    echo "  FAIL key '${AKASH_KEY_NAME}' not in keyring (${AKASH_KEYRING_BACKEND})"
    FAIL=$((FAIL + 1))
  fi

  echo ""
  echo "==> Node"
  check "RPC reachable" provider-services status --node "${AKASH_NODE}"
fi

if [[ -n "${AKASH_JWT:-}" ]]; then
  echo ""
  echo "  ok   AKASH_JWT set (${#AKASH_JWT} chars)"
  PASS=$((PASS + 1))
fi

echo ""
if (( FAIL > 0 )); then
  echo "RESULT: ${PASS} passed, ${FAIL} failed — fix issues before deploying"
  exit 1
fi
echo "RESULT: ${PASS} checks passed — ready to deploy"
echo ""
echo "Next (keyring — simplest):"
echo "  AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml"
echo ""
echo "Next (Vault production):"
echo "  USE_VAULT_AKASH=1 ./deploy.sh"

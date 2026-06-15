#!/usr/bin/env bash
# Shared Akash auth helpers — keyring (default) or pre-generated JWT.
set -euo pipefail

_AKASH_AUTH_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
[[ -f "${_AKASH_AUTH_LIB}/jwt-utils.sh" ]] && source "${_AKASH_AUTH_LIB}/jwt-utils.sh"

akash__require_env() {
  : "${AKASH_KEY_NAME:?AKASH_KEY_NAME is required}"
  : "${AKASH_NODE:=https://rpc.akashnet.net:443}"
  : "${AKASH_CHAIN_ID:=akashnet-2}"
  : "${AKASH_GAS:=auto}"
  : "${AKASH_GAS_ADJUSTMENT:=1.4}"
  : "${AKASH_GAS_PRICES:=0.025uakt}"
  : "${AKASH_KEYRING_BACKEND:=test}"
  export AKASH_NODE AKASH_CHAIN_ID AKASH_GAS AKASH_GAS_ADJUSTMENT AKASH_GAS_PRICES AKASH_KEYRING_BACKEND
}

# Tx commands always use the local keyring (--from).
akash_tx_flags() {
  akash__require_env
  printf '%s\n' \
    --from "${AKASH_KEY_NAME}" \
    --node "${AKASH_NODE}" \
    --chain-id "${AKASH_CHAIN_ID}" \
    --gas "${AKASH_GAS}" \
    --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
    --gas-prices "${AKASH_GAS_PRICES}" \
    --keyring-backend "${AKASH_KEYRING_BACKEND}"
}

# send-manifest: JWT if valid; auto-fallback to keyring on expiry.
akash_manifest_auth_flags() {
  akash__require_env
  if declare -F akash_jwt_export >/dev/null 2>&1; then
    akash_jwt_export 2>/dev/null || true
    local status
    status="$(akash_jwt_status 2>/dev/null || echo missing)"
    if [[ "${status}" == "valid" || "${status}" == "stale" ]]; then
      if [[ -n "${AKASH_JWT:-}" ]]; then
        printf '%s\n' --token "${AKASH_JWT}"
        return
      fi
      if [[ -n "${AKASH_JWT_FILE:-}" && -r "${AKASH_JWT_FILE}" ]]; then
        printf '%s\n' --token-file "${AKASH_JWT_FILE}"
        return
      fi
    fi
    if [[ "${status}" == "expired" ]]; then
      echo "akash-auth: JWT expired — falling back to keyring for send-manifest" >&2
    fi
  else
    if [[ -n "${AKASH_JWT:-}" ]]; then
      printf '%s\n' --token "${AKASH_JWT}"
      return
    fi
    if [[ -n "${AKASH_JWT_FILE:-}" && -r "${AKASH_JWT_FILE}" ]]; then
      printf '%s\n' --token-file "${AKASH_JWT_FILE}"
      return
    fi
  fi
  printf '%s\n' --from "${AKASH_KEY_NAME}" --keyring-backend "${AKASH_KEYRING_BACKEND}"
}

akash_account_address() {
  akash__require_env
  if [[ -n "${AKASH_ACCOUNT_ADDRESS:-}" ]]; then
    echo "${AKASH_ACCOUNT_ADDRESS}"
    return
  fi
  provider-services keys show "${AKASH_KEY_NAME}" -a \
    --keyring-backend "${AKASH_KEYRING_BACKEND}" 2>/dev/null
}

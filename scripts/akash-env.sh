#!/usr/bin/env bash
# Load standard Akash environment (Codespace / deploy/config.env).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"

# deploy/config.env if present
if [[ -f "${ROOT}/deploy/config.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "${ROOT}/deploy/config.env" && set +a
fi

# Sensible defaults for mainnet
export PATH="${PATH}:${HOME}/bin:/root/bin"
export AKASH_NODE="${AKASH_NODE:-https://rpc.akashnet.net:443}"
export AKASH_CHAIN_ID="${AKASH_CHAIN_ID:-akashnet-2}"
export AKASH_GAS="${AKASH_GAS:-auto}"
export AKASH_GAS_ADJUSTMENT="${AKASH_GAS_ADJUSTMENT:-1.25}"
export AKASH_GAS_PRICES="${AKASH_GAS_PRICES:-0.025uakt}"
export AKASH_KEYRING_BACKEND="${AKASH_KEYRING_BACKEND:-test}"
export AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm}"

# Persisted JWT from generate script
if [[ -f "${ROOT}/.run/akash-jwt.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/.run/akash-jwt.env"
fi

echo "Akash env loaded:"
echo "  AKASH_NODE=${AKASH_NODE}"
echo "  AKASH_CHAIN_ID=${AKASH_CHAIN_ID}"
echo "  AKASH_KEY_NAME=${AKASH_KEY_NAME}"
echo "  AKASH_KEYRING_BACKEND=${AKASH_KEYRING_BACKEND}"
echo "  AKASH_AUTH_METHOD=${AKASH_AUTH_METHOD:-keyring}"
if [[ -n "${AKASH_JWT:-}" ]]; then
  echo "  AKASH_JWT=eyJ... (${#AKASH_JWT} chars)"
fi

#!/usr/bin/env bash
# Deploy AgentSwarm to Akash with Vault-injected secrets.
#
# Prerequisites:
#   - akash CLI configured with wallet
#   - VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID exported in shell
#   - Docker image pushed to a registry Akash providers can pull
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.internal:8200
#   export VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
#   export VAULT_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)
#   ./deploy/akash/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDL="${SCRIPT_DIR}/deploy.yaml"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID}"
: "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID}"

if ! command -v akash >/dev/null 2>&1; then
  echo "akash CLI not found. Install: https://docs.akash.network/docs/deployments/akash-cli/install" >&2
  exit 1
fi

# Substitute deploy-time Vault credentials into SDL without writing secrets to disk.
SDL_RENDERED="$(mktemp)"
trap 'rm -f "${SDL_RENDERED}"' EXIT

envsubst '${VAULT_ADDR} ${VAULT_ROLE_ID} ${VAULT_SECRET_ID}' < "${SDL}" > "${SDL_RENDERED}"

echo "Creating Akash deployment from ${SDL_RENDERED}"
akash tx deploy create "${SDL_RENDERED}" \
  --from "${AKASH_WALLET:-default}" \
  --node "${AKASH_NODE:-https://rpc.akash.network:443}" \
  --chain-id "${AKASH_CHAIN_ID:-akashnet-2}" \
  --gas-prices "${AKASH_GAS_PRICES:-0.025uakt}" \
  --gas auto \
  --gas-adjustment 1.5 \
  -y

echo "Deployment submitted. Monitor with: akash lease-status"

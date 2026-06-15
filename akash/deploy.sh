#!/usr/bin/env bash
# Deploy YieldSwarm to Akash with runtime Vault secret injection.
# secret_id is passed at deploy time — never stored in SDL or git.
set -euo pipefail

: "${AKASH_KEY_NAME:?Set AKASH_KEY_NAME}"
: "${AKASH_NET:?Set AKASH_NET (e.g. mainnet)}"
: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID}"
: "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID — generate via: vault write -f auth/approle/role/yieldswarm-akash/secret-id}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDL="${SCRIPT_DIR}/deploy.yaml"
DEPOSIT="${AKASH_DEPOSIT:-5000000uakt}"

export VAULT_ADDR VAULT_ROLE_ID VAULT_SECRET_ID

echo "Creating deployment from ${SDL}"
akash tx deployment create "${SDL}" \
  --from "${AKASH_KEY_NAME}" \
  --node "https://rpc.${AKASH_NET}.akash.network:443" \
  --chain-id "akashnet-${AKASH_NET}" \
  --gas auto \
  --gas-adjustment 1.5 \
  --deposit "${DEPOSIT}" \
  -y

echo "Deployment submitted. Monitor with: akash query deployment list --owner <address>"

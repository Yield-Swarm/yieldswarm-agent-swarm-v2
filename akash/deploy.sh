#!/usr/bin/env bash
# Deploy YieldSwarm to Akash with Vault-injected secrets.
# Requires: akash CLI, VAULT_ADDR, VAULT_TOKEN (akash-deploy AppRole or admin)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDL_FILE="${SDL_FILE:-$SCRIPT_DIR/deploy.yaml}"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN (akash-deploy AppRole token)}"
: "${AKASH_FROM:?Set AKASH_FROM (wallet address)}"
: "${AKASH_KEYRING_BACKEND:?Set AKASH_KEYRING_BACKEND}"
: "${AKASH_CHAIN_ID:=akashnet-2}"
: "${AKASH_NODE:?Set AKASH_NODE}"

echo "==> Fetching Akash deploy credentials from Vault..."
DEPLOY_SECRETS=$(vault kv get -format=json secret/yieldswarm/akash/deploy)
CERTIFICATE=$(echo "$DEPLOY_SECRETS" | jq -r '.data.data.certificate')
KEY=$(echo "$DEPLOY_SECRETS" | jq -r '.data.data.key')

CERT_DIR=$(mktemp -d)
trap 'rm -rf "$CERT_DIR"' EXIT
echo "$CERTIFICATE" > "$CERT_DIR/cert.pem"
echo "$KEY" > "$CERT_DIR/key.pem"

echo "==> Generating single-use akash-runtime secret-id..."
RUNTIME_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
RUNTIME_SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/akash-runtime/secret-id)

echo "==> Creating deployment with Vault-injected env vars..."
akash tx deployment create "$SDL_FILE" \
  --from "$AKASH_FROM" \
  --keyring-backend "$AKASH_KEYRING_BACKEND" \
  --chain-id "$AKASH_CHAIN_ID" \
  --node "$AKASH_NODE" \
  --home "$CERT_DIR" \
  --env "VAULT_ROLE_ID=$RUNTIME_ROLE_ID" \
  --env "VAULT_SECRET_ID=$RUNTIME_SECRET_ID" \
  --yes

echo "==> Deployment submitted. Secret-id was single-use and is now consumed."
echo "    Monitor: akash query deployment list --owner $AKASH_FROM --node $AKASH_NODE"

#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# akash/deploy-shards.sh
# Deploys all 120 AgentSwarm shards to Akash Network.
#
# For each shard:
#   1. Generates a fresh response-wrapped secret_id from Vault (10 min TTL,
#      single-use) so each container gets a unique, short-lived credential.
#   2. Renders a per-shard SDL with the correct AGENT_SHARD_ID and secret_id.
#   3. Submits the deployment to Akash.
#
# Prerequisites:
#   - akash CLI installed and wallet funded with AKT
#   - VAULT_ADDR and VAULT_TOKEN (admin) exported
#   - AKASH_KEYNAME, AKASH_NODE, AKASH_CHAIN_ID exported
#   - VAULT_ROLE_ID (akash-runtime role_id) exported
# ---------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

: "${VAULT_ADDR:?}"
: "${VAULT_TOKEN:?}"
: "${VAULT_ROLE_ID:?}"
: "${AKASH_KEYNAME:?}"
: "${AKASH_NODE:?}"
: "${AKASH_CHAIN_ID:?}"

SHARD_COUNT="${SHARD_COUNT:-120}"
AGENTS_PER_SHARD="${AGENTS_PER_SHARD:-84}"
IMAGE="${IMAGE:-ghcr.io/yieldswarm/agentswarm-os:latest}"
SDL_TEMPLATE="${SDL_TEMPLATE:-$(dirname "$0")/deploy.yaml}"
VAULT_HOSTNAME="${VAULT_HOSTNAME:-$(echo "${VAULT_ADDR}" | sed 's|https://||;s|:.*||')}"

echo "Deploying ${SHARD_COUNT} shards to Akash ..."

for i in $(seq 0 $(( SHARD_COUNT - 1 ))); do
  echo "[shard ${i}] Generating wrapped secret_id ..."
  WRAPPED=$(vault write -wrap-ttl=10m -field=wrapping_token -f \
    auth/approle/role/akash-runtime/secret-id)

  # Build per-shard SDL from the template
  SDL_FILE="/tmp/agentswarm-shard-${i}.yaml"
  sed \
    -e "s|<VAULT_HOSTNAME>|${VAULT_HOSTNAME}|g" \
    -e "s|<AKASH_RUNTIME_ROLE_ID>|${VAULT_ROLE_ID}|g" \
    -e "s|<WRAPPED_SECRET_ID>|${WRAPPED}|g" \
    -e "s|AGENT_SHARD_ID=0|AGENT_SHARD_ID=${i}|g" \
    -e "s|ghcr.io/yieldswarm/agentswarm-os:latest|${IMAGE}|g" \
    "${SDL_TEMPLATE}" > "${SDL_FILE}"

  echo "[shard ${i}] Submitting deployment ..."
  akash tx deployment create "${SDL_FILE}" \
    --from "${AKASH_KEYNAME}" \
    --node "${AKASH_NODE}" \
    --chain-id "${AKASH_CHAIN_ID}" \
    --gas auto \
    --gas-adjustment 1.4 \
    --fees 5000uakt \
    -y

  echo "[shard ${i}] Deployment submitted."
  rm -f "${SDL_FILE}"

  # Avoid hammering the chain RPC
  sleep 1
done

echo "All ${SHARD_COUNT} shards deployed."

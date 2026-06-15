#!/usr/bin/env bash
# =============================================================================
# deploy.sh
# -----------------------------------------------------------------------------
# End-to-end deploy script for the AgentSwarm OS Akash workload. Performs:
#
#   1. Mint a fresh, response-wrapped secret_id for the `akash-runtime` AppRole.
#   2. Render deploy.yaml with VAULT_ROLE_ID + VAULT_SECRET_ID_WRAP_TOKEN
#      injected into the env block (in-memory only - never written to disk).
#   3. Pipe the rendered manifest directly to `akash tx deployment create`.
#
# Required env:
#   VAULT_ADDR              URL of Vault
#   VAULT_TOKEN             a token with the `secrets-rotator` policy attached
#                           (or any token allowed to create secret-ids for the
#                           akash-runtime AppRole)
#   AKASH_KEY_NAME          akash keyring entry name
#   AKASH_NODE              akash RPC node URL
#   AKASH_CHAIN_ID          akash chain id (e.g. akashnet-2)
#   AGENT_SHARD_ID          0..119
# =============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit

: "${VAULT_ADDR:?}"
: "${VAULT_TOKEN:?}"
: "${AKASH_KEY_NAME:?}"
: "${AKASH_NODE:?}"
: "${AKASH_CHAIN_ID:?}"
: "${AGENT_SHARD_ID:=0}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDL="${HERE}/../deploy.yaml"

log() { printf '\033[1;34m[deploy]\033[0m %s\n' "$*" >&2; }

log "Fetching role_id for akash-runtime"
ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"

log "Minting wrapped secret_id (TTL=300s, single-use)"
WRAP_TOKEN="$(
  VAULT_WRAP_TTL=300s vault write -f -field=wrapping_token \
    auth/approle/role/akash-runtime/secret-id
)"

log "Rendering SDL in memory and creating deployment"
# Use yq to merge env values into the SDL without leaving plaintext on disk.
if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required (https://github.com/mikefarah/yq)" >&2
  exit 127
fi

rendered="$(
  yq eval "
    .services.agentswarm.env = (
      .services.agentswarm.env
      | map(select(. != \"VAULT_ROLE_ID\" and . != \"VAULT_SECRET_ID_WRAP_TOKEN\" and . != \"AGENT_SHARD_ID\"))
      + [
        \"VAULT_ROLE_ID=${ROLE_ID}\",
        \"VAULT_SECRET_ID_WRAP_TOKEN=${WRAP_TOKEN}\",
        \"AGENT_SHARD_ID=${AGENT_SHARD_ID}\"
      ]
    )
  " "$SDL"
)"

# Pipe directly - never write to disk.
printf '%s' "$rendered" | akash tx deployment create /dev/stdin \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE" \
  --chain-id "$AKASH_CHAIN_ID" \
  --keyring-backend os \
  --gas auto --gas-adjustment 1.4 -y

log "Deployment submitted. Akash provider will pull the image and start the container."
log "The wrapped secret_id has a 5-minute TTL; if the provider takes longer,"
log "re-run this script to mint a fresh one."

#!/usr/bin/env bash
# deploy.sh
# Renders the Akash SDL with a freshly-minted, response-wrapped secret_id
# for the akash-workload AppRole, then submits the deployment.
#
# Required env:
#   VAULT_ADDR              - Vault endpoint reachable from this runner.
#   VAULT_TOKEN             - has the ci-pipeline policy.
#   YIELDSWARM_IMAGE        - container image to deploy (registry/repo:tag).
#   AKASH_KEY_NAME          - keyring entry to sign with.
#
# Optional:
#   VAULT_ROLE_NAME         - default akash-workload
#   VAULT_APPROLE_MOUNT     - default approle
#   WRAP_TTL                - default 60s (must be enough for the
#                             container to start AND unwrap).
#   AKASH_NODE / AKASH_CHAIN_ID / AKASH_KEYRING_BACKEND - as per akash CLI.

set -Eeuo pipefail

: "${VAULT_ADDR:?VAULT_ADDR required}"
: "${VAULT_TOKEN:?VAULT_TOKEN required (ci-pipeline policy)}"
: "${YIELDSWARM_IMAGE:?YIELDSWARM_IMAGE required}"
: "${AKASH_KEY_NAME:?AKASH_KEY_NAME required}"

for c in vault envsubst provider-services jq; do
    command -v "$c" >/dev/null || { echo "missing dependency: $c" >&2; exit 1; }
done

ROLE_NAME="${VAULT_ROLE_NAME:-akash-workload}"
APPROLE_MOUNT="${VAULT_APPROLE_MOUNT:-approle}"
WRAP_TTL="${WRAP_TTL:-60s}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

VAULT_ROLE_ID=$(vault read -field=role_id \
    "auth/${APPROLE_MOUNT}/role/${ROLE_NAME}/role-id")

VAULT_WRAPPED_SECRET_ID=$(vault write -wrap-ttl="$WRAP_TTL" -force \
    -field=wrapping_token \
    "auth/${APPROLE_MOUNT}/role/${ROLE_NAME}/secret-id")

# Drop our admin token immediately - the rest of the pipeline only needs
# the akash keyring.
unset VAULT_TOKEN

export VAULT_ADDR VAULT_ROLE_ID VAULT_WRAPPED_SECRET_ID YIELDSWARM_IMAGE

rendered="$(mktemp --tmpdir akash-deploy.XXXXXX.yaml)"
trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT

# envsubst expands ONLY our explicit allow-list - it will not touch
# unrelated $foo placeholders that might appear in image tags etc.
# (single quotes are intentional: the arg is a literal variable list,
#  not a value to interpolate.)
# shellcheck disable=SC2016
envsubst '${VAULT_ADDR} ${VAULT_ROLE_ID} ${VAULT_WRAPPED_SECRET_ID} ${YIELDSWARM_IMAGE}' \
    < "$SCRIPT_DIR/deploy.yaml" > "$rendered"

# Clear the wrapping token from this shell as soon as it's in the file -
# the file is on a tmpfs and gets shredded by the EXIT trap.
unset VAULT_WRAPPED_SECRET_ID

echo "[deploy] submitting rendered SDL to Akash"
provider-services tx deployment create "$rendered" \
    --from "$AKASH_KEY_NAME" \
    --keyring-backend "${AKASH_KEYRING_BACKEND:-os}" \
    --node "${AKASH_NODE:-https://rpc.akashnet.net:443}" \
    --chain-id "${AKASH_CHAIN_ID:-akashnet-2}" \
    --gas auto --gas-adjustment 1.3 --gas-prices 0.025uakt \
    --yes -o json | jq '.txhash, .height, .raw_log' >&2

echo "[deploy] submitted. Wrapping token expires in ${WRAP_TTL}; container must unwrap before then."

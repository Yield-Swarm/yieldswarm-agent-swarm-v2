#!/usr/bin/env bash
# Deploy AgentSwarm to Akash with Vault-injected secrets and JWT auth (AEP-63/64).
#
# Uses provider-services CLI (v0.10+) which auto-generates short-lived JWTs.
# Wallet mnemonic is pulled from Vault at deploy time — never stored in git/SDL.
#
# Prerequisites:
#   - provider-services CLI installed
#   - VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID exported
#   - Docker image pushed to a registry Akash providers can pull
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.internal:8200
#   export VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
#   export VAULT_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)
#   ./deploy/akash/verify-env.sh   # optional but recommended
#   ./deploy/akash/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDL="${SCRIPT_DIR}/deploy.yaml"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID}"
: "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID}"

if ! command -v provider-services >/dev/null 2>&1; then
  echo "provider-services CLI not found. Install: https://akash.network/docs/developers/deployment/cli/installation-guide/" >&2
  exit 1
fi

# Configure Akash auth from Vault (JWT default via provider-services)
# shellcheck source=setup-auth.sh
source "${SCRIPT_DIR}/setup-auth.sh"
configure_akash_auth

render_sdl() {
  local template="$1" output="$2"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst '${VAULT_ADDR} ${VAULT_ROLE_ID} ${VAULT_SECRET_ID}' < "${template}" > "${output}"
  else
    python3 - "${template}" "${output}" <<'PY'
import os, sys
text = open(sys.argv[1]).read()
for key in ("VAULT_ADDR", "VAULT_ROLE_ID", "VAULT_SECRET_ID"):
    text = text.replace("${%s}" % key, os.environ.get(key, ""))
open(sys.argv[2], "w").write(text)
PY
  fi
}

# Substitute deploy-time Vault credentials into SDL without writing secrets to disk.
SDL_RENDERED="$(mktemp)"
trap 'rm -f "${SDL_RENDERED}"' EXIT

render_sdl "${SDL}" "${SDL_RENDERED}"

echo "Creating Akash deployment (auth=${AKASH_AUTH_METHOD}, account=${AKASH_ACCOUNT_ADDRESS})"
provider-services tx deployment create "${SDL_RENDERED}" \
  --from "${AKASH_KEY_NAME}" \
  --keyring-backend "${AKASH_KEYRING_BACKEND}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --gas-prices "${AKASH_GAS_PRICES}" \
  --gas "${AKASH_GAS}" \
  --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
  -y

echo "Deployment submitted. Monitor with: provider-services query deployment list --owner ${AKASH_ACCOUNT_ADDRESS} --node ${AKASH_NODE}"

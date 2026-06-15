#!/usr/bin/env bash
# Deploy Bittensor dual-purpose miner to Akash Mainnet.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SDL_TEMPLATE="${REPO_ROOT}/deploy/akash-bittensor-miner.sdl.yml"
PS="${PROVIDER_SERVICES_BIN:-provider-services}"

export PATH="${REPO_ROOT}/bin:${PATH}"
[[ -x "${REPO_ROOT}/bin/provider-services" ]] && PS="${REPO_ROOT}/bin/provider-services"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID}"
: "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID}"
: "${BT_NETUID:?Set BT_NETUID}"

DEPLOY_IMAGE="${DEPLOY_IMAGE:-ghcr.io/yield-swarm/bittensor-miner:latest}"
BT_NETWORK="${BT_NETWORK:-finney}"
BT_WALLET_NAME="${BT_WALLET_NAME:-miner}"
BT_HOTKEY_NAME="${BT_HOTKEY_NAME:-default}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-false}"
PREFERRED_PROVIDER="${PREFERRED_PROVIDER:-akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc}"

# shellcheck source=akash/setup-auth.sh
source "${SCRIPT_DIR}/akash/setup-auth.sh"
configure_akash_auth

export DEPLOY_IMAGE BT_NETWORK BT_WALLET_NAME BT_HOTKEY_NAME OLLAMA_MODEL VAULT_SKIP_VERIFY
export BT_NETUID AKASH_DSEQ="" AKASH_PROVIDER=""

SDL_RENDERED="$(mktemp)"
trap 'rm -f "${SDL_RENDERED}"' EXIT

if command -v envsubst >/dev/null 2>&1; then
  envsubst '${VAULT_ADDR} ${VAULT_ROLE_ID} ${VAULT_SECRET_ID} ${VAULT_SKIP_VERIFY} ${DEPLOY_IMAGE} ${BT_NETUID} ${BT_NETWORK} ${BT_WALLET_NAME} ${BT_HOTKEY_NAME} ${OLLAMA_MODEL} ${AKASH_DSEQ} ${AKASH_PROVIDER}' \
    < "${SDL_TEMPLATE}" > "${SDL_RENDERED}"
else
  python3 - "${SDL_TEMPLATE}" "${SDL_RENDERED}" <<'PY'
import os, sys
text = open(sys.argv[1]).read()
for k in ("VAULT_ADDR","VAULT_ROLE_ID","VAULT_SECRET_ID","VAULT_SKIP_VERIFY","DEPLOY_IMAGE","BT_NETUID","BT_NETWORK","BT_WALLET_NAME","BT_HOTKEY_NAME","OLLAMA_MODEL","AKASH_DSEQ","AKASH_PROVIDER"):
    text = text.replace("${%s}" % k, os.environ.get(k,""))
open(sys.argv[2],"w").write(text)
PY
fi

"${PS}" sdl-to-manifest "${SDL_RENDERED}" -o json >/dev/null
echo "Creating Bittensor miner deployment (netuid=${BT_NETUID}, image=${DEPLOY_IMAGE})"

TX_JSON="$("${PS}" tx deployment create "${SDL_RENDERED}" \
  --from "${AKASH_KEY_NAME}" --keyring-backend "${AKASH_KEYRING_BACKEND}" \
  --node "${AKASH_NODE}" --chain-id "${AKASH_CHAIN_ID}" \
  --gas-prices "${AKASH_GAS_PRICES}" --gas auto --gas-adjustment 1.5 -y --output json)"

DSEQ="$(echo "${TX_JSON}" | jq -r '[.events[]? | select(.type=="akash.v1.EventDeploymentCreated") | .attributes[]? | select(.key=="dseq") | .value][0] // empty')"
echo "Deployment dseq=${DSEQ} — run bid/lease flow or use deploy/akash/deploy-full.sh pattern"

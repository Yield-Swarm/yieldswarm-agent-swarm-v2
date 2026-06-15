#!/usr/bin/env bash
# Deploy dual-purpose Bittensor miner to Akash (telemetry :8080 + axon :8091).
#
# Mints a response-wrapped Vault SecretID and passes bootstrap env vars into
# the Akash deployment via deploy-to-akash.sh.
#
# Usage:
#   export BT_NETUID=1
#   export VAULT_ADDR VAULT_TOKEN    # operator token to mint wrap
#   ./scripts/deploy-bittensor.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SDL_TEMPLATE="${REPO_ROOT}/deploy/akash-bittensor-miner.sdl.yml"

: "${BT_NETUID:?Set BT_NETUID}"

export DEPLOY_IMAGE="${DEPLOY_IMAGE:-ghcr.io/yield-swarm/bittensor-miner:latest}"
export BT_NETWORK="${BT_NETWORK:-finney}"
export BT_WALLET_NAME="${BT_WALLET_NAME:-miner}"
export BT_HOTKEY_NAME="${BT_HOTKEY_NAME:-default}"
export OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
export VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-false}"
export HEALTH_PATH="/health"
export STATE_FILE="${REPO_ROOT}/.run/akash-bittensor-deploy.json"
export AKASH_GPU_MODEL="${AKASH_GPU_MODEL:-rtx3090}"

# Vault runtime injection for bittensor-runtime AppRole
export VAULT_INJECT_RUNTIME_SECRETS="${VAULT_INJECT_RUNTIME_SECRETS:-yes}"
export VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-bittensor-runtime}"
export VAULT_WRAP_TTL="${VAULT_WRAP_TTL:-600s}"
export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"

RENDERED="$(mktemp)"
trap 'rm -f "${RENDERED}"' EXIT

render_sdl() {
  if command -v envsubst >/dev/null 2>&1; then
    envsubst '${DEPLOY_IMAGE}' < "${SDL_TEMPLATE}" > "${RENDERED}"
  else
    python3 - "${SDL_TEMPLATE}" "${RENDERED}" <<'PY'
import os, sys
text = open(sys.argv[1]).read()
text = text.replace("${DEPLOY_IMAGE}", os.environ.get("DEPLOY_IMAGE", ""))
open(sys.argv[2], "w").write(text)
PY
  fi
}

render_sdl
echo "[bittensor-deploy] netuid=${BT_NETUID} image=${DEPLOY_IMAGE} vault_role=${VAULT_AKASH_ROLE}"

"${SCRIPT_DIR}/deploy-to-akash.sh" deploy "${RENDERED}"

echo "[bittensor-deploy] state: ${STATE_FILE}"
echo "[bittensor-deploy] Arena: src/app/arena?workers=https://<lease-uri>:8080"

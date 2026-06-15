#!/usr/bin/env bash
# Deploy dual-purpose Bittensor miner to Akash (telemetry :8080 + axon :8091).
#
# Wraps scripts/deploy-to-akash.sh with SDL rendering for deploy/akash-bittensor-miner.sdl.yml
#
# Usage:
#   export BT_NETUID=1
#   export VAULT_ADDR VAULT_ROLE_ID VAULT_SECRET_ID   # optional
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
export AKASH_DSEQ="" AKASH_PROVIDER=""
export HEALTH_PATH="/health"
export STATE_FILE="${REPO_ROOT}/.run/akash-bittensor-deploy.json"
export AKASH_GPU_MODEL="${AKASH_GPU_MODEL:-rtx3090}"

RENDERED="$(mktemp)"
trap 'rm -f "${RENDERED}"' EXIT

render_sdl() {
  if command -v envsubst >/dev/null 2>&1; then
    envsubst < "${SDL_TEMPLATE}" > "${RENDERED}"
  else
    python3 - "${SDL_TEMPLATE}" "${RENDERED}" <<'PY'
import os, sys
text = open(sys.argv[1]).read()
for k in ("VAULT_ADDR","VAULT_ROLE_ID","VAULT_SECRET_ID","VAULT_SKIP_VERIFY","DEPLOY_IMAGE",
          "BT_NETUID","BT_NETWORK","BT_WALLET_NAME","BT_HOTKEY_NAME","OLLAMA_MODEL",
          "AKASH_DSEQ","AKASH_PROVIDER"):
    text = text.replace("${%s}" % k, os.environ.get(k, ""))
open(sys.argv[2], "w").write(text)
PY
  fi
}

render_sdl
echo "[bittensor-deploy] netuid=${BT_NETUID} image=${DEPLOY_IMAGE}"

"${SCRIPT_DIR}/deploy-to-akash.sh" deploy "${RENDERED}"

echo "[bittensor-deploy] state: ${STATE_FILE}"
echo "[bittensor-deploy] Arena: src/app/arena?workers=https://<lease-uri>:8080"

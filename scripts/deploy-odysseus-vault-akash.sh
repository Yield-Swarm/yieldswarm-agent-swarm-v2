#!/usr/bin/env bash
# Deploy Odysseus stack to Akash with secrets pulled from Vault at render time.
#
# Renders deploy/akash-odysseus.sdl.yml after exporting KV paths to env vars.
# Does not bake secrets into the SDL file on disk.
#
# Usage:
#   eval "$(./scripts/akash-vault-prepare.sh odysseus-runtime)"
#   ./scripts/deploy-odysseus-vault-akash.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SDL_TEMPLATE="${REPO_ROOT}/deploy/akash-odysseus.sdl.yml"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
export VAULT_SECRET_PATHS="${VAULT_SECRET_PATHS:-runtime/odysseus,runtime/llm,runtime/core,rpc/solana}"

VAULT_ENV="$(mktemp)"
trap 'rm -f "${VAULT_ENV}" "${RENDERED:-}"' EXIT

export PYTHONPATH="${REPO_ROOT}:${REPO_ROOT}/agents"
if ! python3 "${SCRIPT_DIR}/vault-export-env.py" odysseus > "${VAULT_ENV}"; then
  echo "[odysseus-vault] ERROR: failed to export Vault secrets" >&2
  exit 1
fi
# shellcheck disable=SC1090
set -a && source "${VAULT_ENV}" && set +a

# Map Vault exports to SDL placeholders
export YIELDSWARM_ROUTER_API_KEY="${YIELDSWARM_ROUTER_API_KEY:-${router_api_key:-changeme}}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
export FIREWORKS_API_KEY="${FIREWORKS_API_KEY:-}"
export ODYSSEUS_API_KEY="${ODYSSEUS_API_KEY:-}"
export ODYSSEUS_ADMIN_PASSWORD="${ODYSSEUS_ADMIN_PASSWORD:-${ODYSSEUS_API_KEY:-}}"
export STATE_FILE="${REPO_ROOT}/.run/akash-odysseus-deploy.json"
export HEALTH_PATH="/healthz"

RENDERED="$(mktemp)"
if command -v envsubst >/dev/null 2>&1; then
  envsubst < "${SDL_TEMPLATE}" > "${RENDERED}"
else
  cp "${SDL_TEMPLATE}" "${RENDERED}"
fi

echo "[odysseus-vault] deploying with Vault-rendered secrets (not written to git)"
"${SCRIPT_DIR}/deploy-to-akash.sh" deploy "${RENDERED}"
echo "[odysseus-vault] state: ${STATE_FILE}"

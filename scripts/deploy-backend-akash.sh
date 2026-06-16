#!/usr/bin/env bash
# Deploy integration backend to Akash (Arena API :8080, Vault-injected secrets).
#
# Usage:
#   ./scripts/akash-vault-prepare.sh integration-backend
#   ./scripts/deploy-backend-akash.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SDL_TEMPLATE="${REPO_ROOT}/deploy/akash-backend.sdl.yml"

export DEPLOY_IMAGE="${DEPLOY_IMAGE:-ghcr.io/yieldswarm/yieldswarm-backend:latest}"
export AKASH_OWNER_ADDRESS="${AKASH_OWNER_ADDRESS:-}"
export AKASH_CONSOLE_API="${AKASH_CONSOLE_API:-https://console-api.akash.network/v1}"
export ODYSSEUS_BRAIN_URL="${ODYSSEUS_BRAIN_URL:-}"
export VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-false}"
export HEALTH_PATH="/api/health"
export STATE_FILE="${REPO_ROOT}/.run/akash-backend-deploy.json"
export AKASH_SDL="${RENDERED:-}"

RENDERED="$(mktemp)"
trap 'rm -f "${RENDERED}"' EXIT

render_sdl() {
  if command -v envsubst >/dev/null 2>&1; then
    envsubst '${DEPLOY_IMAGE} ${AKASH_OWNER_ADDRESS} ${AKASH_CONSOLE_API} ${ODYSSEUS_BRAIN_URL} \
${VAULT_ADDR} ${VAULT_ROLE_ID} ${VAULT_SECRET_ID} ${VAULT_SKIP_VERIFY}' \
      < "${SDL_TEMPLATE}" > "${RENDERED}"
  else
    python3 - "${SDL_TEMPLATE}" "${RENDERED}" <<'PY'
import os, sys
text = open(sys.argv[1]).read()
for k in (
    "DEPLOY_IMAGE", "AKASH_OWNER_ADDRESS", "AKASH_CONSOLE_API", "ODYSSEUS_BRAIN_URL",
    "VAULT_ADDR", "VAULT_ROLE_ID", "VAULT_SECRET_ID", "VAULT_SKIP_VERIFY",
):
    text = text.replace("${%s}" % k, os.environ.get(k, ""))
    text = text.replace("${%s:-%s}" % (k, ""), os.environ.get(k, ""))
open(sys.argv[2], "w").write(text)
PY
  fi
}

if [[ -z "${VAULT_ADDR:-}" || -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ]]; then
  echo "[backend-deploy] WARN: VAULT_ADDR/ROLE_ID/SECRET_ID not set — run scripts/akash-vault-prepare.sh first" >&2
fi

render_sdl
echo "[backend-deploy] image=${DEPLOY_IMAGE} owner=${AKASH_OWNER_ADDRESS:-<vault>}"

"${SCRIPT_DIR}/deploy-to-akash.sh" deploy "${RENDERED}"

echo "[backend-deploy] state: ${STATE_FILE}"
echo "[backend-deploy] health: curl https://<lease-uri>/api/health"

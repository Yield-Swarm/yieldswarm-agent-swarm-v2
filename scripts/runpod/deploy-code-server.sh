#!/usr/bin/env bash
# deploy-code-server.sh — RunPod master: browser IDE on localhost (SSH tunnel access)
#
# Usage:
#   export CODE_SERVER_PASSWORD=...   # or deploy/collab/env.collab
#   ./scripts/runpod/deploy-code-server.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/deploy/collab/env.collab"
WORKSPACE="${CODE_SERVER_WORKSPACE:-/workspace/yieldswarm-agent-swarm-v2}"
BIND="${CODE_SERVER_BIND:-127.0.0.1}"
PORT="${CODE_SERVER_PORT:-8080}"
SESSION="${CODE_SERVER_SCREEN_SESSION:-code_workspace}"

log() { printf '[code-server] %s\n' "$*" >&2; }

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

: "${CODE_SERVER_PASSWORD:?Set CODE_SERVER_PASSWORD in deploy/collab/env.collab}"

# Prefer Docker compose when available
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  log "starting via docker compose (bind ${BIND}:${PORT})"
  cd "${REPO_ROOT}/deploy/collab"
  export CODE_SERVER_WORKSPACE="${WORKSPACE}"
  docker compose up -d code-server
  log "OK — tunnel: ssh -N -L ${PORT}:127.0.0.1:${PORT} <pod>@ssh.runpod.io"
  exit 0
fi

# Fallback: native install + screen
if ! command -v code-server >/dev/null 2>&1; then
  log "installing code-server..."
  curl -fsSL https://code-server.dev/install.sh | sh
fi

mkdir -p "${WORKSPACE}"
if [[ ! -d "${WORKSPACE}/.git" ]] && [[ -d "${REPO_ROOT}/.git" ]]; then
  WORKSPACE="${REPO_ROOT}"
fi

if command -v screen >/dev/null 2>&1; then
  screen -S "${SESSION}" -X quit 2>/dev/null || true
  screen -dmS "${SESSION}" bash -lc \
    "code-server --auth password --bind-addr ${BIND}:${PORT} '${WORKSPACE}'"
  log "screen session: ${SESSION}"
else
  log "WARN: screen not found — run manually:"
  log "  code-server --auth password --bind-addr ${BIND}:${PORT} '${WORKSPACE}'"
fi

log "password: (from CODE_SERVER_PASSWORD / config.yaml if auto-generated)"
log "tunnel from laptop: ./scripts/collab/ssh-tunnel-workspace.sh"

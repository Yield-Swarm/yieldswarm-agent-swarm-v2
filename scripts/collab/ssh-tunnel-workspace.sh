#!/usr/bin/env bash
# ssh-tunnel-workspace.sh — Map RunPod code-server (+ optional Jitsi) to localhost
#
# Usage:
#   export RUNPOD_SSH_HOST=io3xh1krei03ju-644120be@ssh.runpod.io
#   export SSH_KEY_PATH=~/.ssh/id_ed25519
#   ./scripts/collab/ssh-tunnel-workspace.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/deploy/collab/.env.collab"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

HOST="${RUNPOD_SSH_HOST:?Set RUNPOD_SSH_HOST}"
KEY="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
CS_PORT="${CODE_SERVER_PORT:-8080}"
JITSI_PORT="${JITSI_HTTPS_PORT:-8443}"
ENABLE_JITSI="${TUNNEL_JITSI:-0}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "${KEY}")

log() { printf '[ssh-tunnel] %s\n' "$*" >&2; }

FORWARDS=(-N -L "${CS_PORT}:127.0.0.1:${CS_PORT}")
if [[ "${ENABLE_JITSI}" == "1" ]]; then
  FORWARDS+=(-L "${JITSI_PORT}:127.0.0.1:${JITSI_PORT}")
fi

log "tunneling ${HOST} → localhost:${CS_PORT} (code-server)"
[[ "${ENABLE_JITSI}" == "1" ]] && log "also Jitsi → localhost:${JITSI_PORT}"
log "open http://localhost:${CS_PORT} in browser (Ctrl+C to stop tunnel)"

exec ssh "${SSH_OPTS[@]}" "${FORWARDS[@]}" "${HOST}"

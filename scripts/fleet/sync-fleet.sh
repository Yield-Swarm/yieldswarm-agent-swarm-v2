#!/usr/bin/env bash
# Push fleet matrix + provisioner to remote Termux / RunPod hosts.
#
# Usage:
#   ./scripts/fleet/sync-fleet.sh termux phone.example.com
#   ./scripts/fleet/sync-fleet.sh runpod user@runpod-host
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${2:-}"
PROFILE="${1:-}"

[[ -n "${TARGET}" ]] || {
  echo "Usage: $0 <termux|runpod> <user@host>" >&2
  exit 1
}

[[ -f "${REPO_ROOT}/.env.fleet" ]] || {
  echo "ERROR: .env.fleet missing — cp .env.fleet.example .env.fleet" >&2
  exit 1
}

REMOTE_DIR="${REMOTE_DIR:-~/yieldswarm-agent-swarm-v2}"

log() { printf '[sync-fleet] %s\n' "$*"; }

log "sync → ${TARGET}:${REMOTE_DIR}"
rsync -avz \
  "${REPO_ROOT}/.env.fleet" \
  "${REPO_ROOT}/.env.fleet.example" \
  "${REPO_ROOT}/swarm_provision.sh" \
  "${REPO_ROOT}/scripts/fleet/" \
  "${TARGET}:${REMOTE_DIR}/"

ssh "${TARGET}" "chmod +x ${REMOTE_DIR}/swarm_provision.sh ${REMOTE_DIR}/scripts/fleet/*.sh 2>/dev/null || true"

if [[ -n "${HF_TOKEN:-}" ]]; then
  log "installing HF agent skills on remote (HF_TOKEN set)"
  ssh "${TARGET}" "cd ${REMOTE_DIR} && HF_TOKEN='${HF_TOKEN}' ./scripts/fleet/install-hf-agent-skills.sh" || \
    log "WARN: remote HF skills install failed"
fi

case "${PROFILE}" in
  termux)
    log "remote: ./swarm_provision.sh 0"
    ssh "${TARGET}" "cd ${REMOTE_DIR} && ./swarm_provision.sh 0"
    ;;
  runpod)
    log "remote: ./swarm_provision.sh 7"
    ssh "${TARGET}" "cd ${REMOTE_DIR} && ./swarm_provision.sh 7"
    ;;
  *)
    log "files synced — run ./swarm_provision.sh <0-8> on remote"
    ;;
esac

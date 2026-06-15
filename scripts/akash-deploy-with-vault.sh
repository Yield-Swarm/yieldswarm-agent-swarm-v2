#!/usr/bin/env bash
# Production Akash deploy with Vault runtime injection.
# Delegates to deploy-to-akash.sh for full lifecycle + state files.
#
# Usage:
#   ./scripts/akash-deploy-with-vault.sh [sdl-file]
#   SDL_FILE=deploy/akash-bittensor-miner.sdl.yml VAULT_AKASH_ROLE=bittensor-runtime ./scripts/akash-deploy-with-vault.sh
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/.." && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib/vault-env.sh" 2>/dev/null || true

SDL_FILE="${1:-${SDL_FILE:-deploy/deploy-swarm-monolith.yaml}}"
VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
WRAP_TTL="${VAULT_WRAP_TTL:-600s}"
AUTO_HEAL="${AUTO_HEAL:-1}"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [akash-deploy-vault] $*"; }
fail() { log "ERROR: $*"; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"; }

maybe_start_heal() {
  if [[ "${AUTO_HEAL}" != "1" ]]; then
    return 0
  fi
  if [[ -f "${RUN_DIR}/akash-lease.env" ]] && [[ -x "${REPO_ROOT}/deploy/akash/auto-heal.sh" ]]; then
    log "starting auto-heal daemon (reads ${RUN_DIR}/akash-lease.env)"
    nohup "${REPO_ROOT}/deploy/akash/auto-heal.sh" --daemon \
      >"${RUN_DIR}/akash-auto-heal.log" 2>&1 &
    echo $! > "${RUN_DIR}/auto-heal.pid"
  fi
}

main() {
  require_cmd provider-services
  require_cmd jq
  [[ -f "${SDL_FILE}" || -f "${REPO_ROOT}/${SDL_FILE}" ]] || fail "SDL not found: ${SDL_FILE}"

  export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
  export AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"
  export VAULT_INJECT_RUNTIME_SECRETS=yes
  export VAULT_AKASH_ROLE
  export VAULT_WRAP_TTL="${WRAP_TTL}"
  export REPO_ROOT
  export RUN_DIR

  log "preflight (Vault + wallet + SDL)"
  "${HERE}/akash-preflight.sh" "${SDL_FILE}" || fail "preflight NO-GO"

  log "deploying with Vault injection role=${VAULT_AKASH_ROLE}"
  "${HERE}/deploy-to-akash.sh" deploy "${SDL_FILE}"

  maybe_start_heal
  log "complete — state: ${RUN_DIR}/akash-deploy.json, ${RUN_DIR}/akash-lease.env"
  log "verify: ./scripts/verify-akash-lease.sh"
}

main "$@"

#!/usr/bin/env bash
# Production Akash deploy: mint Vault wrapped SecretID, render SDL, deploy, manifest.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/.." && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib/vault-env.sh"
# shellcheck disable=SC1091
source "${HERE}/lib/vault-akash-bootstrap.sh"

SDL_FILE="${1:-deploy/deploy-swarm-monolith.yaml}"
VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
WRAP_TTL="${VAULT_WRAP_TTL:-600s}"
AUTO_HEAL="${AUTO_HEAL:-1}"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [akash-deploy-vault] $*"; }
fail() { log "ERROR: $*"; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"; }

deploy_with_vault_env() {
  export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
  export AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"
  export AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"
  export VAULT_INJECT_RUNTIME_SECRETS=yes
  export VAULT_AKASH_ROLE
  export VAULT_WRAP_TTL="${WRAP_TTL}"
  export REPO_ROOT

  "${HERE}/akash-deploy.sh" "${SDL_FILE}"
}

maybe_start_heal() {
  if [ "${AUTO_HEAL}" != "1" ]; then
    return 0
  fi
  if [ -x "${REPO_ROOT}/deploy/akash/auto-heal.sh" ]; then
    log "starting auto-heal daemon"
    nohup "${REPO_ROOT}/deploy/akash/auto-heal.sh" --daemon >/tmp/yieldswarm-akash-heal.log 2>&1 &
  fi
}

main() {
  require_cmd provider-services
  require_cmd jq
  [ -f "${SDL_FILE}" ] || fail "SDL not found: ${SDL_FILE}"

  deploy_with_vault_env
  maybe_start_heal
  log "deploy complete — secrets will be rendered at runtime by Vault Agent"
}

main "$@"

#!/usr/bin/env bash
# Production Akash deploy: mint Vault wrapped SecretID, render SDL, deploy, manifest.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib/vault-env.sh"

SDL_FILE="${1:-deploy/deploy-swarm-monolith.yaml}"
VAULT_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
WRAP_TTL="${VAULT_WRAP_TTL:-600s}"
AUTO_HEAL="${AUTO_HEAL:-1}"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [akash-deploy-vault] $*"; }
fail() { log "ERROR: $*"; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"; }

mint_vault_bootstrap() {
  require_cmd vault
  require_cmd jq
  [ -n "${VAULT_ADDR:-}" ] || fail "VAULT_ADDR is required"

  local token
  token="$(vault__read_secret_value VAULT_TOKEN VAULT_TOKEN_FILE 2>/dev/null || true)"
  if [ -z "$token" ]; then
    fail "Set VAULT_TOKEN or VAULT_TOKEN_FILE for bootstrap AppRole wrapping"
  fi
  export VAULT_TOKEN="$token"

  log "minting wrapped SecretID for role ${VAULT_ROLE} (ttl ${WRAP_TTL})"
  VAULT_WRAPPED_SECRET_ID="$(
    vault write -wrap-ttl="${WRAP_TTL}" -force -format=json \
      "auth/approle/role/${VAULT_ROLE}/secret-id" | jq -r '.wrap_info.token'
  )"
  VAULT_ROLE_ID="$(
    vault read -field=role_id -format=json "auth/approle/role/${VAULT_ROLE}/role-id"
  )"
  export VAULT_WRAPPED_SECRET_ID VAULT_ROLE_ID
  log "wrapped SecretID minted (single-use, expires in ${WRAP_TTL})"
}

deploy_with_vault_env() {
  export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
  export AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"
  export AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"

  # Pass Vault bootstrap vars into the Akash deployment create transaction.
  VAULT_ROLE_ID="${VAULT_ROLE_ID}" \
  VAULT_WRAPPED_SECRET_ID="${VAULT_WRAPPED_SECRET_ID}" \
  AGENT_SHARD_ID="${AGENT_SHARD_ID}" \
  "${HERE}/akash-deploy.sh" "${SDL_FILE}"
}

maybe_start_heal() {
  if [ "${AUTO_HEAL}" != "1" ]; then
    return 0
  fi
  if [ -x "${HERE}/../deploy/akash/auto-heal.sh" ]; then
    log "starting auto-heal daemon"
    nohup "${HERE}/../deploy/akash/auto-heal.sh" --daemon >/tmp/yieldswarm-akash-heal.log 2>&1 &
  fi
}

main() {
  require_cmd provider-services
  require_cmd jq
  [ -f "${SDL_FILE}" ] || fail "SDL not found: ${SDL_FILE}"

  mint_vault_bootstrap
  deploy_with_vault_env
  maybe_start_heal
  log "deploy complete — secrets will be rendered at runtime by Vault Agent"
}

main "$@"

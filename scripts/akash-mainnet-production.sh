#!/usr/bin/env bash
# Production Akash mainnet deploy — Vault Agent auto-injection + optional Cherry preflight.
#
# Pipeline:
#   1. Vault connectivity + wrapped SecretID mint readiness
#   2. Cherry Servers API (multicloud operator — Vault-backed, optional)
#   3. Akash preflight (wallet, SDL, tmpfs secrets mount)
#   4. Akash deploy with Vault Agent runtime injection
#   5. Auto-heal daemon (optional)
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.io:8200
#   export VAULT_TOKEN=...                    # operator — mint wrap only
#   export CHERRY_SERVERS_API_KEY=...         # seed via vault/scripts/seed-secrets.sh first
#   ./scripts/akash-mainnet-production.sh
#
#   SKIP_CHERRY_PREFLIGHT=1  — skip Cherry API probe
#   SDL_FILE=deploy/deploy-swarm-monolith.yaml
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/.." && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib/vault-env.sh" 2>/dev/null || true

SDL_FILE="${SDL_FILE:-deploy/deploy-swarm-monolith.yaml}"
SKIP_CHERRY="${SKIP_CHERRY_PREFLIGHT:-0}"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"

log()  { printf '[akash-mainnet] %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }

require_vault() {
  step "Vault operator connectivity"
  : "${VAULT_ADDR:?Set VAULT_ADDR}"
  if [[ -z "${VAULT_TOKEN:-}" && -z "${VAULT_ROLE_ID:-}" ]]; then
    log "ERROR: VAULT_TOKEN or AppRole credentials required for wrap mint"
    exit 1
  fi
  if command -v vault >/dev/null 2>&1 && [[ -n "${VAULT_TOKEN:-}" ]]; then
    vault status >/dev/null || { log "ERROR: Vault unreachable at ${VAULT_ADDR}"; exit 1; }
  fi
  log "Vault OK: ${VAULT_ADDR}"
}

maybe_cherry() {
  if [[ "${SKIP_CHERRY}" == "1" ]]; then
    log "SKIP_CHERRY_PREFLIGHT=1 — skipping Cherry Servers probe"
    return 0
  fi
  step "Cherry Servers (Vault-backed API key)"
  if bash "${HERE}/cherry-vault-preflight.sh"; then
    log "Cherry preflight passed"
  else
    log "WARN: Cherry preflight failed — continue if Cherry is not in use"
    [[ "${CHERRY_REQUIRED:-0}" == "1" ]] && exit 1
  fi
}

main() {
  echo "================================================================="
  echo "YIELDSWARM — AKASH MAINNET PRODUCTION (Vault Agent injection)"
  echo "================================================================="
  require_vault
  maybe_cherry
  step "Akash mainnet deploy (Vault wrap → SDL → vault-agent)"
  export VAULT_INJECT_RUNTIME_SECRETS=yes
  export AUTO_HEAL="${AUTO_HEAL:-1}"
  bash "${HERE}/akash-deploy-with-vault.sh" "${SDL_FILE}"
  echo "================================================================="
  echo "COMPLETE — verify: ./scripts/verify-akash-lease.sh"
  echo "State: ${RUN_DIR}/akash-deploy.json  ${RUN_DIR}/akash-lease.env"
  echo "================================================================="
}

main "$@"

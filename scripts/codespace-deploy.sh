#!/usr/bin/env bash
# =============================================================================
# YieldSwarm Codespace / CI Production Deploy
# =============================================================================
# Vault-first deployment flow for GitHub Codespaces or any clean Linux host.
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.io:8200
#   export VAULT_ROLE_ID=<approle-role-id>
#   export VAULT_SECRET_ID=<approle-secret-id>   # or VAULT_WRAPPED_SECRET_ID
#   ./scripts/codespace-deploy.sh
#
# Steps:
#   0. Preflight + Vault secret injection
#   1. Bootstrap Vault policies (if fresh cluster)
#   2. Build & push images
#   3. Deploy Akash monolith (Vault Agent sidecar)
#   4. Deploy Odysseus stack
#   5. Start monitoring + sovereign loops
# =============================================================================
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/vault-env.sh
. "${ROOT_DIR}/scripts/lib/vault-env.sh"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [codespace-deploy] $*"; }
fail() { log "ERROR: $*"; exit 1; }

DRY_RUN="${DRY_RUN:-0}"
SKIP_VAULT_BOOTSTRAP="${SKIP_VAULT_BOOTSTRAP:-1}"
VAULT_RUNTIME_PATH="${VAULT_RUNTIME_PATH:-kv/data/yieldswarm/akash/runtime}"
VAULT_DEPLOY_PATH="${VAULT_DEPLOY_PATH:-kv/data/yieldswarm/deploy}"

preflight() {
  log "Running preflight checks..."
  for cmd in docker curl jq make git; do
    command -v "$cmd" >/dev/null 2>&1 || fail "missing required command: $cmd"
  done
  [ -n "${VAULT_ADDR:-}" ] || fail "VAULT_ADDR is required"
  log "Preflight OK"
}

load_secrets() {
  log "Loading secrets from Vault path: ${VAULT_RUNTIME_PATH}"
  vault_export_env "${VAULT_RUNTIME_PATH}"

  if [ -f "${ROOT_DIR}/deploy/config.env" ]; then
    # shellcheck disable=SC1091
    . "${ROOT_DIR}/deploy/config.env"
  elif [ -f "${ROOT_DIR}/deploy/config.env.example" ]; then
    log "WARNING: deploy/config.env not found — copy from deploy/config.env.example"
  fi
}

bootstrap_vault() {
  if [ "$SKIP_VAULT_BOOTSTRAP" = "1" ]; then
    log "Skipping Vault bootstrap (SKIP_VAULT_BOOTSTRAP=1)"
    return 0
  fi
  log "Bootstrapping Vault..."
  bash "${ROOT_DIR}/vault/setup/bootstrap.sh"
}

deploy_images() {
  log "Step 1/4 — Build & push Docker images"
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] make build"
  else
    make -C "${ROOT_DIR}" build
  fi
}

deploy_akash() {
  log "Step 2/4 — Deploy Akash monolith with Vault Agent"
  export AKASH_SDL="${AKASH_SDL:-${ROOT_DIR}/deploy/deploy-swarm-monolith.yaml}"

  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] scripts/akash-deploy.sh ${AKASH_SDL}"
  else
    AUTO_SELECT_BID=1 bash "${ROOT_DIR}/scripts/akash-deploy.sh" "${AKASH_SDL}"
    bash "${ROOT_DIR}/deploy/akash/auto-heal.sh" --daemon &
  fi
}

deploy_odysseus() {
  log "Step 3/4 — Deploy Odysseus production stack"
  export ODYSSEUS_DEPLOY_VAULT_PATH="${VAULT_DEPLOY_PATH}"

  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] scripts/deploy-production-odysseus.sh akash"
  else
    bash "${ROOT_DIR}/scripts/deploy-production-odysseus.sh" akash
  fi
}

start_services() {
  log "Step 4/4 — Start monitoring + sovereign loops + Kairo API"
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] make monitoring-up sovereign-up"
    log "[dry-run] python -m kairo.api.server"
  else
    make -C "${ROOT_DIR}" monitoring-up sovereign-up
    nohup python3 -m kairo.api.server > /tmp/kairo-api.log 2>&1 &
    log "Kairo API started (pid $!) — logs at /tmp/kairo-api.log"
  fi
}

print_summary() {
  cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║  YieldSwarm Codespace Deploy — Complete                      ║
╠══════════════════════════════════════════════════════════════╣
║  Vault:     \${VAULT_ADDR}                                   ║
║  Akash SDL: \${AKASH_SDL:-deploy/deploy-swarm-monolith.yaml} ║
║  Odysseus:  scripts/deploy-production-odysseus.sh akash      ║
║  Kairo API: http://localhost:3001/api/kairo/dashboard      ║
║  Monitor:   http://localhost:3000 (Grafana via make help)      ║
╚══════════════════════════════════════════════════════════════╝

Next: verify health
  curl -s http://localhost:3001/api/kairo/health
  curl -s http://localhost:8080/api/health   # backend integration server

EOF
}

main() {
  preflight
  load_secrets
  bootstrap_vault
  deploy_images
  deploy_akash
  deploy_odysseus
  start_services
  print_summary
}

main "$@"

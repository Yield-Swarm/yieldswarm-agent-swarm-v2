#!/usr/bin/env bash
# =============================================================================
# scripts/cross-threshold.sh — Live cross: Bifröst + Sovereign Loops + TV Command
#
# You chose to cross. This script validates secrets, pins the bridge, boots the
# backend, starts sovereign loop daemons, and wires the command dashboard.
#
# Usage (VM / production host):
#   cp .env.example .env   # fill VAULT_SECRET_TOKEN, SOVEREIGN_LOOP_KEY, etc.
#   ./scripts/cross-threshold.sh
#
# Options:
#   --dry-run     Preview steps without starting services
#   --treasury-live   Enable LUDACRIS_TREASURY_LIVE=1 (on-chain routes — irreversible)
#
# Env:
#   PORT                    Backend port (default 8080)
#   SKIP_VAULT=1            Skip HashiCorp Vault inject
#   SHIVA_CROSS_FORCE=1     Cross even if sovereign env keys missing (simulation)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

PORT="${PORT:-8080}"
API_BASE="${API_BASE:-http://127.0.0.1:${PORT}}"
LOG_DIR="${REPO_ROOT}/.run/cross-threshold"
DEPLOY_LOG="${LOG_DIR}/cross.log"
DRY_RUN=0
TREASURY_LIVE=0

mkdir -p "${LOG_DIR}"

log() {
  local msg="[cross-threshold] $(date -u +%FT%TZ) $*"
  echo "$msg" | tee -a "${DEPLOY_LOG}"
}

die() { log "FATAL: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --treasury-live) TREASURY_LIVE=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Unknown option: $1" ;;
  esac
done

load_env() {
  [[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a
  [[ -f .env ]] && set -a && source .env && set +a
  [[ -f config/ludacris-mayhem.env ]] && set -a && source config/ludacris-mayhem.env && set +a
}

inject_vault() {
  if [[ "${SKIP_VAULT:-0}" == "1" ]]; then
    log "SKIP_VAULT=1 — using local .env only"
    return 0
  fi
  if [[ -x vault/inject/render-env.sh ]]; then
    log "Vault inject (provider=${PROVIDER:-azure})"
    if [[ "${DRY_RUN}" == "1" ]]; then
      log "[dry-run] would run vault/inject/render-env.sh"
      return 0
    fi
    PROVIDER="${PROVIDER:-azure}" AGENT_ENV_FILE="${AGENT_ENV_FILE:-/tmp/yieldswarm-agent.env}" \
      ./vault/inject/render-env.sh || log "WARN vault inject failed — continuing with .env"
    [[ -f "${AGENT_ENV_FILE:-/tmp/yieldswarm-agent.env}" ]] && set -a && source "${AGENT_ENV_FILE:-/tmp/yieldswarm-agent.env}" && set +a
  fi
}

validate_sovereign() {
  log "Validating sovereign environment keys"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would run node scripts/validate-sovereign-env.mjs --strict"
    return 0
  fi
  if node scripts/validate-sovereign-env.mjs --strict >> "${DEPLOY_LOG}" 2>&1; then
    log "Sovereign env OK"
    return 0
  fi
  if [[ "${SHIVA_CROSS_FORCE:-0}" == "1" ]]; then
    log "WARN sovereign keys missing — SHIVA_CROSS_FORCE=1 simulation cross"
    return 0
  fi
  die "Sovereign env incomplete. Set keys in .env or SHIVA_CROSS_FORCE=1 for simulation."
}

cross_bifrost() {
  log "Pinning Bifröst bridge"
  if [[ "${DRY_RUN}" == "1" ]]; then
    ./scripts/bifrost-deploy.sh --dry-run | tee -a "${DEPLOY_LOG}"
  else
    ./scripts/bifrost-deploy.sh | tee -a "${DEPLOY_LOG}"
  fi
}

start_backend() {
  if curl -sfS "${API_BASE}/api/health" >/dev/null 2>&1; then
    log "Backend already listening on ${API_BASE}"
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would start backend on port ${PORT}"
    return 0
  fi
  log "Installing backend deps (if needed)"
  (cd backend && npm install --silent 2>/dev/null || true)
  export PORT SOVEREIGN_LOOP_AUTO_START=1
  export LUDACRIS_MAYHEM_MODE=1
  export MAYHEM_MODE_ENABLED=true
  log "Starting backend (sovereign loops auto-start)"
  nohup node backend/src/server.js >> "${LOG_DIR}/backend.log" 2>&1 &
  echo $! > "${LOG_DIR}/backend.pid"
  local i
  for i in $(seq 1 45); do
    if curl -sfS "${API_BASE}/api/health" >/dev/null 2>&1; then
      log "Backend healthy"
      return 0
    fi
    sleep 1
  done
  die "Backend failed to become healthy — see ${LOG_DIR}/backend.log"
}

wire_sovereign() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would POST ${API_BASE}/api/sovereign/loops/start"
    return 0
  fi
  log "Starting sovereign loop daemon"
  curl -sfS -X POST "${API_BASE}/api/sovereign/loops/start" >> "${LOG_DIR}/sovereign-start.json" 2>>"${DEPLOY_LOG}" || true
  curl -sfS "${API_BASE}/api/sovereign/loops" >> "${LOG_DIR}/sovereign-snapshot.json" 2>>"${DEPLOY_LOG}" || true
  log "Sovereign tick (economic + replication + heal)"
  curl -sfS -X POST "${API_BASE}/api/sovereign/loops/tick" >> "${LOG_DIR}/sovereign-tick.json" 2>>"${DEPLOY_LOG}" || true
}

wire_command() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would wire ludacris mayhem + command overview"
    return 0
  fi
  log "Wiring 14 pillars + 3 solenoids + command dashboard"
  API_BASE="${API_BASE}" LUDACRIS_TREASURY_LIVE="${TREASURY_LIVE}" \
    bash scripts/ludacris-mayhem-live.sh >> "${LOG_DIR}/mayhem.log" 2>&1 \
    || log "WARN mayhem wire partial — see ${LOG_DIR}/mayhem.log"
  curl -sfS "${API_BASE}/api/command/overview" >> "${LOG_DIR}/command.json" 2>>"${DEPLOY_LOG}" || true
}

print_urls() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '127.0.0.1')"
  log "══════════════════════════════════════════"
  log " THRESHOLD CROSSED — surfaces live"
  log "══════════════════════════════════════════"
  log "TV Command:     http://${ip}:${PORT}/command"
  log "TV alt:         http://${ip}:${PORT}/tv"
  log "Sovereign API:  http://${ip}:${PORT}/api/sovereign/loops"
  log "React panel:    http://${ip}:5173/sovereign  (cd frontend && npm run dev)"
  log "Audit log:      ${DEPLOY_LOG}"
  log "Bifröst log:    .run/bifrost/deployment.log"
}

main() {
  log "=== CROSS THRESHOLD — live deploy begin (dry_run=${DRY_RUN}) ==="
  load_env
  inject_vault
  validate_sovereign
  cross_bifrost
  start_backend
  wire_sovereign
  wire_command
  print_urls
  log "=== CROSS COMPLETE ==="
}

main "$@"

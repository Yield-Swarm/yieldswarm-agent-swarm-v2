#!/usr/bin/env bash
# =============================================================================
# scripts/claim-grail.sh — Strike sovereign overrides + claim Grail (treasury live)
#
# "Strike and Claim the Grail"
#   Strike  — force replicate + trigger patch + sovereign tick
#   Claim   — cross-threshold with LUDACRIS_TREASURY_LIVE=1 (on-chain routes)
#
# Usage:
#   ./scripts/claim-grail.sh
#   ./scripts/claim-grail.sh --dry-run
#   ./scripts/claim-grail.sh --skip-build   # skip cargo release compile
#
# Requires .env with sovereign keys OR SHIVA_CROSS_FORCE=1 for simulation.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

PORT="${PORT:-8080}"
API_BASE="${API_BASE:-http://127.0.0.1:${PORT}}"
LOG_DIR="${REPO_ROOT}/.run/claim-grail"
STRIKE_LOG="${LOG_DIR}/strike.log"
DRY_RUN=0
SKIP_BUILD=0

mkdir -p "${LOG_DIR}"

log() {
  local msg="[claim-grail] $(date -u +%FT%TZ) $*"
  echo "$msg" | tee -a "${STRIKE_LOG}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

strike() {
  local path="$1"
  local label="$2"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] STRIKE ${label} → POST ${path}"
    return 0
  fi
  log "STRIKE ${label}"
  local out="${LOG_DIR}/$(basename "${path}").json"
  curl -sfS -X POST "${API_BASE}${path}" -o "${out}" 2>>"${STRIKE_LOG}" || {
    log "WARN strike ${label} failed — is backend up with sovereign routes?"
    return 1
  }
  local state
  state="$(python3 -c "import json; print(json.load(open('${out}')).get('state','?'))" 2>/dev/null || echo '?')"
  log "  → state: ${state}"
}

wait_api() {
  local i
  for i in $(seq 1 60); do
    if curl -sfS "${API_BASE}/api/health" >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  return 1
}

main() {
  log "══════════════════════════════════════════"
  log " STRIKE AND CLAIM THE GRAIL"
  log "══════════════════════════════════════════"

  if [[ "${SKIP_BUILD}" != "1" ]]; then
    log "Phase 0 — build in binary"
    if [[ "${DRY_RUN}" == "1" ]]; then
      log "[dry-run] would run ./scripts/build-binary.sh"
    else
      ./scripts/build-binary.sh >> "${LOG_DIR}/build.log" 2>&1
    fi
  fi

  log "Phase 1 — CLAIM (cross-threshold --treasury-live)"
  local cross_args=(--treasury-live)
  [[ "${DRY_RUN}" == "1" ]] && cross_args+=(--dry-run)
  PORT="${PORT}" API_BASE="${API_BASE}" SKIP_VAULT="${SKIP_VAULT:-1}" \
    bash scripts/cross-threshold.sh "${cross_args[@]}" \
    >> "${LOG_DIR}/cross.log" 2>&1 || log "WARN cross-threshold partial — continuing strike"

  log "Phase 2 — STRIKE (sovereign overrides)"
  wait_api || log "WARN API not ready — strikes may fail"

  strike "/api/sovereign/loops/force-replicate" "Force Replicate"
  strike "/api/sovereign/loops/trigger-patch" "Trigger Patch"
  strike "/api/sovereign/loops/tick" "Full Tick"
  strike "/api/sovereign/loops/force-rebalance" "Force Rebalance"

  if [[ "${DRY_RUN}" != "1" ]]; then
    curl -sfS "${API_BASE}/api/sovereign/loops" -o "${LOG_DIR}/grail-snapshot.json" 2>>"${STRIKE_LOG}" || true
    curl -sfS "${API_BASE}/api/command/overview" -o "${LOG_DIR}/command-snapshot.json" 2>>"${STRIKE_LOG}" || true
    log "Grail snapshot → ${LOG_DIR}/grail-snapshot.json"
  fi

  log "══════════════════════════════════════════"
  log " GRAIL CLAIMED — treasury live · strikes complete"
  log " TV: ${API_BASE}/command"
  log " Log: ${STRIKE_LOG}"
  log "══════════════════════════════════════════"
}

main "$@"

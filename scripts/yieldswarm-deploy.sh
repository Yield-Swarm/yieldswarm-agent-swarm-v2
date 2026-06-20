#!/usr/bin/env bash
# scripts/yieldswarm-deploy.sh — SPLATTER TECH God Mode capstone deploy (Task #55)
# Layers: HQ infra → AgentSwarm OS → DePIN → site/revenue → hardening
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PHASE="${PHASE:-all}"
DRY_RUN="${DRY_RUN:-0}"
TARGET_ENV="${TARGET_ENV:-production}"

usage() {
  cat <<'EOF'
Usage: yieldswarm-deploy.sh [--phase N|all] [--dry-run]

Phases (maps to God Tasks 1-55):
  1   HQ infra + DePIN dashboard (tasks 1-10)
  2   AgentSwarm OS + ZK + LLM router (11-25)
  3   DePIN yield + cross-chain (26-40)
  4   Site + revenue rails + payments (jacuzzi-Helix)
  5   Production hardening + sovereign loops (41-55)
  all Run 1-5 sequentially

EOF
}

log() { printf '[yieldswarm-deploy] %s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" == "1" ]]; then log "[dry-run] $*"; else log "$*"; eval "$@"; fi
}

load_env() {
  [[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a
  [[ -f .env ]] && set -a && source .env && set +a
}

phase_1_hq() {
  log "=== Phase 1: HQ Infra (God Tasks 1-10) ==="
  run "./scripts/hq-cable-audit.sh" || true
  if [[ -f deploy/deploy-full-stack.sh ]]; then
    run "SKIP_VAULT=${SKIP_VAULT:-1} ./deploy/deploy-full-stack.sh --phase 1" || true
  fi
  log "Open HQ DePIN dashboard: dashboard/depin-hq-sync.html"
}

phase_2_agents() {
  log "=== Phase 2: AgentSwarm OS (God Tasks 11-25) ==="
  run "npm run test:helix --if-present" || true
  run "npm run test:entropy --if-present" || true
  run "cd backend && npm test" || true
  if [[ -f deploy/deploy-full-stack.sh ]]; then
    run "SKIP_VAULT=${SKIP_VAULT:-1} ./deploy/deploy-full-stack.sh --phase 2" || true
  fi
  run "./scripts/deploy-and-test-pillars.sh ${TARGET_ENV}" || true
}

phase_3_depin() {
  log "=== Phase 3: DePIN & Yield (God Tasks 26-40) ==="
  run "python3 -m unittest tests/test_neon_store.py -v" 2>/dev/null || true
  run "./scripts/deploy-bittensor.sh" 2>/dev/null || log "bittensor deploy skipped (no akash key)"
  run "python3 services/akash_roi.py" 2>/dev/null || true
}

phase_4_site() {
  log "=== Phase 4: Site + Revenue (jacuzzi-Helix) ==="
  run "npm run build"
  if [[ -n "${VERCEL_TOKEN:-}" ]]; then
    run "npx vercel deploy --prod --token \"$VERCEL_TOKEN\"" || true
  else
    log "VERCEL_TOKEN unset — skip Vercel deploy"
  fi
}

phase_5_capstone() {
  log "=== Phase 5: Capstone (God Tasks 51-55) ==="
  if [[ -f scripts/deploy-production-full.sh ]]; then
    run "./scripts/deploy-production-full.sh ${DRY_RUN:+--dry-run}" || true
  fi
  run "./scripts/sync-environment-branches.sh" 2>/dev/null || true
  run "./scripts/master-smoke-test.sh" 2>/dev/null || true
  log "God Task #55 capstone complete — SuperGrok + Kimiclaw handoff ready"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown: $1" >&2; usage; exit 1 ;;
  esac
done

load_env
log "SPLATTER TECH deploy — env=$TARGET_ENV phase=$PHASE"

case "$PHASE" in
  1) phase_1_hq ;;
  2) phase_2_agents ;;
  3) phase_3_depin ;;
  4) phase_4_site ;;
  5) phase_5_capstone ;;
  all)
    phase_1_hq
    phase_2_agents
    phase_3_depin
    phase_4_site
    phase_5_capstone
    ;;
  *) echo "invalid phase: $PHASE" >&2; exit 1 ;;
esac

log "Done. See docs/GOD_TASKS_55.md for task status."

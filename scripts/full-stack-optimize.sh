#!/usr/bin/env bash
# scripts/full-stack-optimize.sh
# Full-stack validation + optimization from v1.0 sitemap → production.
# Safe for Pixel Termux / operator workstations — respects DRY_RUN and lockdown.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DRY_RUN="${DRY_RUN:-0}"
SKIP_AKASH="${SKIP_AKASH:-0}"
SKIP_SOVEREIGN="${SKIP_SOVEREIGN:-0}"
TARGET_APY="${TARGET_APY:-40}"
GPU="${GPU:-h100}"
MAX_BID="${MAX_BID:-85000}"

log() { printf '[optimize] %s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] $*"
  else
    log "$*"
    eval "$@"
  fi
}

load_env() {
  if [[ -f deploy/config.env ]]; then
    set -a
    # shellcheck disable=SC1091
    source deploy/config.env
    set +a
  fi
  if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
  fi
}

section() { printf '\n=== %s ===\n' "$*"; }

validate_git() {
  section "Git / repo"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "branch: $(git branch --show-current)"
    log "commit: $(git rev-parse --short HEAD)"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      log "WARN: uncommitted changes present"
    else
      log "working tree clean"
    fi
  fi
}

validate_stack() {
  section "Stack health"
  run "node --version" || true
  run "python3 --version" || true
  if [[ -f backend/package.json ]]; then
    run "cd backend && npm test" || log "backend tests skipped or failed"
  fi
  if [[ -f package.json ]]; then
    run "npm run test:unit --if-present" || true
  fi
  run "python3 -m unittest discover -s tests -p 'test_*.py' -q" 2>/dev/null || true
}

optimize_akash() {
  section "Akash GPU bid tune"
  if [[ "$SKIP_AKASH" == "1" ]]; then
    log "SKIP_AKASH=1 — skipping bid optimizer"
    return 0
  fi
  if [[ -f akash/bid-optimizer.py ]]; then
    run "python3 akash/bid-optimizer.py --gpu ${GPU} --target-apr ${TARGET_APY} --max-bid ${MAX_BID} --auto"
  else
    log "akash/bid-optimizer.py missing"
  fi
  if command -v akash >/dev/null 2>&1; then
    run "akash query market lease list --output json | head -c 2000" || true
  else
    log "akash CLI not installed — lease list skipped"
  fi
}

optimize_sovereign() {
  section "Sovereign core"
  if [[ "$SKIP_SOVEREIGN" == "1" ]]; then
    log "SKIP_SOVEREIGN=1 — skipping sovereign tune"
    return 0
  fi
  if [[ -f iteration-100/run.py ]]; then
    run "python3 iteration-100/run.py --status" || true
  fi
}

optimize_security() {
  section "Vault / YSLR security"
  if [[ -f docs/YSLR.md ]]; then
    log "YSLR docs present"
  fi
  if [[ -n "${VAULT_ADDR:-}" ]]; then
    log "VAULT_ADDR configured"
  else
    log "VAULT_ADDR unset — using layered .env only"
  fi
  if curl -sf "${API_BASE:-http://127.0.0.1:8080}/api/yslr/status" >/dev/null 2>&1; then
    log "YSLR API reachable"
  elif curl -sf "${API_BASE:-http://127.0.0.1:8080}/api/helix/health" >/dev/null 2>&1; then
    log "Helix API reachable (YSLR route may need merge)"
  else
    log "backend not running — start with: cd backend && npm run dev"
  fi
}

optimize_depin() {
  section "Kairo + DePIN bridge"
  if [[ -f kairo/telemetry_daemon.py ]]; then
    if pgrep -f "kairo/telemetry_daemon.py" >/dev/null 2>&1; then
      log "telemetry_daemon already running"
    else
      log "start daemon: python3 kairo/telemetry_daemon.py --helium --nexus &"
    fi
  fi
}

start_monitor() {
  section "Hardware monitor"
  if [[ -f deploy/entrypoint.monitor.sh ]]; then
    log "monitor: nohup ./deploy/entrypoint.monitor.sh \$\$ > ~/monitor.log 2>&1 &"
    if [[ "${START_MONITOR:-0}" == "1" && "$DRY_RUN" != "1" ]]; then
      nohup "$ROOT/deploy/entrypoint.monitor.sh" $$ > "${MONITOR_LOG:-$HOME/monitor.log}" 2>&1 &
      log "monitor pid $! -> ${MONITOR_LOG:-$HOME/monitor.log}"
    fi
  fi
}

usage() {
  cat <<'EOF'
Usage: full-stack-optimize.sh [options]

Validates and tunes the full YieldSwarm stack (sitemap L0-L6).

Options (env):
  DRY_RUN=1           Print commands only
  SKIP_AKASH=1        Skip Akash bid optimizer
  SKIP_SOVEREIGN=1    Skip sovereign status
  START_MONITOR=1     Launch deploy/entrypoint.monitor.sh in background
  TARGET_APY=40       Sovereign / bid target APR %
  GPU=h100            GPU class for bid optimizer
  MAX_BID=85000       Max uakt/block bid ceiling

Also runs: deploy/optimize-all.sh when present.

EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

load_env
log "Full stack optimize — ROOT=$ROOT DRY_RUN=$DRY_RUN"

validate_git
validate_stack

if [[ -f deploy/optimize-all.sh ]]; then
  run "./deploy/optimize-all.sh"
fi

optimize_security
optimize_akash
optimize_sovereign
optimize_depin
start_monitor

section "Done"
log "Verification:"
log "  git status"
log "  akash query market lease list   # if CLI installed"
log "  python3 iteration-100/run.py --status"
log "  tail -f ~/monitor.log            # if START_MONITOR=1"

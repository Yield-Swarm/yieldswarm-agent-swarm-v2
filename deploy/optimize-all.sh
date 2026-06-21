#!/usr/bin/env bash
# deploy/optimize-all.sh — layer-specific optimizations (called by full-stack-optimize.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DRY_RUN="${DRY_RUN:-0}"
API_BASE="${API_BASE:-http://127.0.0.1:8080}"

log() { printf '[optimize-all] %s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" == "1" ]]; then log "[dry-run] $*"; else eval "$@"; fi
}

if [[ -f deploy/config.env ]]; then set -a; source deploy/config.env; set +a; fi
if [[ -f .env ]]; then set -a; source .env; set +a; fi

# L0-L1: Helix + Council + Greek layer
optimize_helix() {
  if curl -sf "$API_BASE/api/helix/health" >/dev/null 2>&1; then
    log "Helix: $(curl -s "$API_BASE/api/helix/health" | head -c 120)"
  fi
  if [[ -f scripts/activate-helix.sh ]]; then
    run "HELIX_CHAIN_ENABLED=1 ./scripts/activate-helix.sh status" 2>/dev/null || true
  fi
}

# L2: Arena telemetry refresh
optimize_arena() {
  run "curl -sf '$API_BASE/api/telemetry/helix' >/dev/null" 2>/dev/null || log "arena telemetry offline"
}

# L3: Treasury + Great Delta
optimize_treasury() {
  run "curl -sf '$API_BASE/api/great-delta/health' >/dev/null" 2>/dev/null || true
  run "curl -sf '$API_BASE/api/telemetry/treasury' >/dev/null" 2>/dev/null || true
}

# L4-L6: Akash + Odysseus lease health
optimize_akash_leases() {
  if [[ -f akash/lease-manager.py ]]; then
    run "python3 akash/lease-manager.py --once" 2>/dev/null || log "lease-manager skipped"
  fi
}

# Sovereign: one quiet tick if state stale
optimize_sovereign_tick() {
  local state="$ROOT/dashboard/state.json"
  if [[ -f iteration-100/run.py && -f "$state" ]]; then
    local age=999999
    if command -v stat >/dev/null; then
      age=$(( $(date +%s) - $(stat -c %Y "$state" 2>/dev/null || stat -f %m "$state") ))
    fi
    if (( age > 3600 )); then
      run "python3 iteration-100/run.py --ticks 1 --quiet" || true
    else
      log "sovereign state fresh (${age}s)"
    fi
  fi
}

log "optimize-all starting"
optimize_helix
optimize_arena
optimize_treasury
optimize_akash_leases
optimize_sovereign_tick
log "optimize-all complete"

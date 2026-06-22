#!/usr/bin/env bash
# Helix DNA v2.1 — transition from dry-run to production live-mode.
#
# Disengages IOT_HUB_DRY_RUN, REWARDS_DRY_RUN, MARKETING_DRY_RUN (optional),
# runs preflight, executes full rewards sweep, probes single-pane.
#
# Usage:
#   ./scripts/production/go-live.sh --dry-run          # show plan only
#   HELIX_GO_LIVE=1 ./scripts/production/go-live.sh  # execute live
#
# On Azure VMSS (both instances):
#   tmux attach -t yieldswarm-backend
#   HELIX_GO_LIVE=1 ./scripts/production/go-live.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8080}"
PLAN_ONLY=0
CONFIRM="${HELIX_GO_LIVE:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) PLAN_ONLY=1; shift ;;
    --confirm) CONFIRM=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

log() { printf '[go-live] %s\n' "$*" >&2; }

for f in deploy/akash.env deploy/config.env .env; do
  [[ -f "$f" ]] && set -a && source "$f" && set +a && log "loaded $f" && break
done

log "=== HELIX DNA v2.1 — LIVE MODE TRANSITION ==="
log "backend: ${BACKEND_URL}"
log "confirm: ${CONFIRM} (set HELIX_GO_LIVE=1 to execute live sweeps)"

if [[ "$PLAN_ONLY" == 1 ]]; then
  log "PLAN: export IOT_HUB_DRY_RUN=0 REWARDS_DRY_RUN=0"
  log "PLAN: ./scripts/rewards/sweep-rewards.sh --full"
  log "PLAN: curl ${BACKEND_URL}/api/single-pane/overview"
  exit 0
fi

# ---- Preflight ----
missing=0
for var in VAULT_ADDR; do
  if [[ -z "${!var:-}" ]]; then
    log "WARN: ${var} unset"
    missing=$((missing + 1))
  fi
done
if [[ -z "${VAULT_TOKEN:-}" && -z "${VAULT_ROLE_ID:-}" ]]; then
  log "WARN: VAULT_TOKEN or VAULT_ROLE_ID required for live secrets"
  missing=$((missing + 1))
fi

if curl -sf "${BACKEND_URL}/api/health" >/dev/null 2>&1; then
  log "OK backend health"
else
  log "WARN: backend not reachable at ${BACKEND_URL}"
fi

if [[ "$CONFIRM" != "1" ]]; then
  log "ABORT: dry-run safeguards still active. Re-run with HELIX_GO_LIVE=1"
  log "  export IOT_HUB_DRY_RUN=1 REWARDS_DRY_RUN=1  # current safe defaults"
  exit 2
fi

# ---- Disengage dry-run ----
export IOT_HUB_DRY_RUN=0
export REWARDS_DRY_RUN=0
export MARKETING_DRY_RUN="${MARKETING_DRY_RUN:-1}"

log "IOT_HUB_DRY_RUN=${IOT_HUB_DRY_RUN}"
log "REWARDS_DRY_RUN=${REWARDS_DRY_RUN}"
log "MARKETING_DRY_RUN=${MARKETING_DRY_RUN}"

# ---- IoT register (if scripts present) ----
if [[ -x scripts/iot-hub/register-devices.sh ]]; then
  log "IoT Hub register..."
  ./scripts/iot-hub/register-devices.sh || log "WARN: iot register failed"
fi

# ---- Full rewards pipeline ----
log "Executing rewards reshard → assemble → sweep (LIVE)..."
./scripts/rewards/sweep-rewards.sh --full

# ---- Verify single pane ----
log "Single-pane overview:"
if curl -sf "${BACKEND_URL}/api/single-pane/overview" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  ok:', d.get('ok'))
data = d.get('data') or {}
print('  agents:', (data.get('tv') or {}).get('agents'))
" 2>/dev/null; then
  log "OK single-pane"
else
  log "WARN: single-pane probe failed"
fi

curl -sf "${BACKEND_URL}/api/rewards/status" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  rewards dry_run:', d.get('dry_run'), 'roots:', d.get('root_count'))
" 2>/dev/null || true

log "=== LIVE MODE TRANSITION COMPLETE ==="
log "Monitor: ${BACKEND_URL}/command-center"
log "State: .run/rewards-sweep.json"

#!/usr/bin/env bash
# =============================================================================
# run-all-onchain.sh — Helix swarm node launcher (Termux → RunPod)
#
# Run on each of 16 Termux instances with a unique SWARM_NODE_ID (1–16).
# Staggers startup to protect mobile hotspot NAT from simultaneous bursts.
#
# Usage (per Termux instance):
#   export SWARM_NODE_ID=3    # unique 1..16 on each phone
#   termux-wake-lock
#   cd ~/yieldswarm-agent-swarm-v2
#   npm run run-all-onchain
#
# Or:
#   SWARM_NODE_ID=7 ./scripts/swarm/run-all-onchain.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MATRIX="${SWARM_MATRIX:-${REPO_ROOT}/config/swarm/16-node-matrix.json}"
RUN_DIR="${REPO_ROOT}/.run/swarm-nodes"

log()  { printf '[run-all-onchain] %s\n' "$*"; }
warn() { printf '[run-all-onchain][warn] %s\n' "$*" >&2; }
die()  { printf '[run-all-onchain][fail] %s\n' "$*" >&2; exit 1; }

DRY_RUN=0
SKIP_STAGGER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-stagger) SKIP_STAGGER=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown arg: $1" ;;
  esac
done

SWARM_NODE_ID="${SWARM_NODE_ID:-}"
if [[ -z "${SWARM_NODE_ID}" ]]; then
  die "set SWARM_NODE_ID=1..16 on each Termux instance before launching"
fi

if ! [[ "${SWARM_NODE_ID}" =~ ^[0-9]+$ ]] || [[ "${SWARM_NODE_ID}" -lt 1 ]] || [[ "${SWARM_NODE_ID}" -gt 16 ]]; then
  die "SWARM_NODE_ID must be 1–16 (got ${SWARM_NODE_ID})"
fi

termux_wake_lock() {
  if command -v termux-wake-lock >/dev/null 2>&1; then
    if [[ "${DRY_RUN}" == "1" ]]; then
      log "[dry-run] termux-wake-lock"
    else
      termux-wake-lock || warn "termux-wake-lock failed"
      log "wake-lock engaged — CPU/WiFi stay active"
    fi
  else
    warn "termux-wake-lock not found (not Termux?) — keep device plugged in"
  fi
}

stagger_startup() {
  if [[ "${SKIP_STAGGER}" == "1" ]]; then
    return 0
  fi
  local stagger_sec total
  stagger_sec="$(python3 -c "import json; print(json.load(open('${MATRIX}')).get('stagger_sec', 3))")"
  local delay=$(( (SWARM_NODE_ID - 1) * stagger_sec ))
  log "node ${SWARM_NODE_ID}/16 — stagger sleep ${delay}s (hotspot NAT protection)"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] sleep ${delay}"
    return 0
  fi
  sleep "${delay}"
}

clear_node_cache() {
  log "clearing node cache for SWARM_NODE_ID=${SWARM_NODE_ID}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] rm -rf ${RUN_DIR}/node-${SWARM_NODE_ID}*"
    return 0
  fi
  mkdir -p "${RUN_DIR}"
  rm -f "${RUN_DIR}/node-${SWARM_NODE_ID}.log" \
        "${RUN_DIR}/node-${SWARM_NODE_ID}-state.json" 2>/dev/null || true
}

load_node_tier() {
  python3 - <<PY "${MATRIX}" "${SWARM_NODE_ID}"
import json, sys
matrix = json.load(open(sys.argv[1]))
node = next(n for n in matrix["nodes"] if n["id"] == int(sys.argv[2]))
print(node["tier"])
print(node["model"])
print(node["runpod_host"])
PY
}

start_primary_services() {
  if [[ "${SWARM_NODE_ID}" != "1" ]]; then
    return 0
  fi
  log "primary node — ensuring telemetry backend on :8080"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would start backend if not listening"
    return 0
  fi
  if curl -fsS "http://127.0.0.1:8080/api/health" >/dev/null 2>&1; then
    log "backend already listening"
    return 0
  fi
  if [[ -f "${REPO_ROOT}/scripts/activate-helix.sh" ]]; then
    bash "${REPO_ROOT}/scripts/activate-helix.sh" --skip-loops || warn "helix activation partial"
  fi
  (cd "${REPO_ROOT}/backend" && npm run start >> "${RUN_DIR}/backend-primary.log" 2>&1 &)
  for _ in $(seq 1 30); do
    curl -fsS "http://127.0.0.1:8080/api/health" >/dev/null 2>&1 && return 0
    sleep 1
  done
  warn "backend not reachable — worker will retry telemetry"
}

launch_worker() {
  mapfile -t NODE_META < <(load_node_tier)
  export SWARM_ASSIGNED_TIER="${NODE_META[0]}"
  export SWARM_ASSIGNED_MODEL="${NODE_META[1]}"
  export SWARM_RUNPOD_HOST="${NODE_META[2]}"

  log "launching Helix RunPod worker — tier=${SWARM_ASSIGNED_TIER} model=${SWARM_ASSIGNED_MODEL}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] node ${REPO_ROOT}/scripts/swarm/helix-runpod-worker.js"
    return 0
  fi
  exec node "${REPO_ROOT}/scripts/swarm/helix-runpod-worker.js"
}

main() {
  cd "${REPO_ROOT}"
  termux_wake_lock
  stagger_startup
  clear_node_cache
  start_primary_services
  launch_worker
}

main "$@"

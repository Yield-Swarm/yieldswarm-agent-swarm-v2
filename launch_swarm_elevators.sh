#!/usr/bin/env bash
# launch_swarm_elevators.sh — spawn 14 book-root elevator daemons + Elisazos swarm sync.
#
# Prerequisites (Cursor ENV / .env):
#   SWARM_API_KEY_PRIMARY   — primary orchestration key (falls back to AGENTSWARM_MASTER_KEY)
#   SWARM_API_KEY_BACKEND   — optional secondary gateway (falls back to YIELDSWARM_ROUTER_API_KEY)
#
# Usage:
#   chmod +x launch_swarm_elevators.sh
#   ./launch_swarm_elevators.sh
#   ./launch_swarm_elevators.sh status
#   ./launch_swarm_elevators.sh stop
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"

if [[ -f "${REPO_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "${REPO_ROOT}/.env"
  set +a
fi

LOG_DIR="${REPO_ROOT}/logs"
PID_DIR="${LOG_DIR}/pids"
mkdir -p "$LOG_DIR" "$PID_DIR"

BOOK_ROOTS=(
  "root_01_genesis" "root_02_ledger" "root_03_consensus" "root_04_telemetry"
  "root_05_state" "root_06_networking" "root_07_validation" "root_08_memepool"
  "root_09_execution" "root_10_witness" "root_11_crypt" "root_12_solenoid"
  "root_13_mandelor" "root_14_mainnet"
)

_resolve_primary() {
  if [[ -n "${SWARM_API_KEY_PRIMARY:-}" ]]; then
    printf '%s' "$SWARM_API_KEY_PRIMARY"
    return 0
  fi
  if [[ -n "${AGENTSWARM_MASTER_KEY:-}" ]]; then
    printf '%s' "$AGENTSWARM_MASTER_KEY"
    return 0
  fi
  return 1
}

_cmd_status() {
  echo "Active yieldswarm processes:"
  ps aux | grep -E '[p]ython3 -m yieldswarm\.(core|network)' || true
  echo ""
  echo "PID files:"
  ls -1 "$PID_DIR" 2>/dev/null || echo "(none)"
}

_cmd_stop() {
  for pf in "$PID_DIR"/*.pid; do
    [[ -f "$pf" ]] || continue
    pid="$(tr -d '[:space:]' < "$pf")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "Stopping PID $pid ($(basename "$pf" .pid))..."
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pf"
  done
  echo "Stop signals sent."
}

case "${1:-launch}" in
  status)
    _cmd_status
    exit 0
    ;;
  stop)
    _cmd_stop
    exit 0
    ;;
  launch|"")
    ;;
  -h|--help)
    sed -n '2,14p' "$0"
    exit 0
    ;;
  *)
    echo "Unknown command: $1 (use launch|status|stop)" >&2
    exit 1
    ;;
esac

if ! PRIMARY="$(_resolve_primary)"; then
  echo "⚠️  Error: SWARM_API_KEY_PRIMARY is not set in Cursor ENV vars." >&2
  echo "    Set SWARM_API_KEY_PRIMARY or AGENTSWARM_MASTER_KEY in .env / Cursor secrets." >&2
  exit 1
fi
export SWARM_API_KEY_PRIMARY="$PRIMARY"

echo "🔄 Initializing 14 Book Root Elevators..."
echo "🔐 Using API Key Authentication: ${SWARM_API_KEY_PRIMARY:0:6}******"

for i in "${!BOOK_ROOTS[@]}"; do
  ROOT_NAME="${BOOK_ROOTS[$i]}"
  NODE_ID=$((i + 1))
  PID_FILE="${PID_DIR}/elevator_${ROOT_NAME}.pid"
  LOG_FILE="${LOG_DIR}/elevator_${ROOT_NAME}.log"

  if [[ -f "$PID_FILE" ]]; then
    old_pid="$(tr -d '[:space:]' < "$PID_FILE")"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
      echo "⏭️  Elevator [$NODE_ID/14] $ROOT_NAME already running (pid $old_pid)"
      continue
    fi
  fi

  echo "⚡ Spawning Elevator Process [$NODE_ID/14] for $ROOT_NAME..."
  nohup python3 -m yieldswarm.core \
    --root "$ROOT_NAME" \
    --node-id "$NODE_ID" \
    --auth "$SWARM_API_KEY_PRIMARY" \
    >> "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 0.5
done

echo "⚙️  Initializing Elisazos Swarm synchronization..."
SWARM_PID_FILE="${PID_DIR}/elisazos_swarm.pid"
if [[ -f "$SWARM_PID_FILE" ]]; then
  swarm_pid="$(tr -d '[:space:]' < "$SWARM_PID_FILE")"
  if [[ -n "$swarm_pid" ]] && kill -0 "$swarm_pid" 2>/dev/null; then
    echo "⏭️  Elisazos swarm already running (pid $swarm_pid)"
  else
    nohup python3 -m yieldswarm.network \
      --swarm-mode elisazos \
      --key "$SWARM_API_KEY_PRIMARY" \
      ${SWARM_API_KEY_BACKEND:+--backend-key "$SWARM_API_KEY_BACKEND"} \
      >> "${LOG_DIR}/elisazos_swarm.log" 2>&1 &
    echo $! > "$SWARM_PID_FILE"
  fi
else
  nohup python3 -m yieldswarm.network \
    --swarm-mode elisazos \
    --key "$SWARM_API_KEY_PRIMARY" \
    ${SWARM_API_KEY_BACKEND:+--backend-key "$SWARM_API_KEY_BACKEND"} \
    >> "${LOG_DIR}/elisazos_swarm.log" 2>&1 &
  echo $! > "$SWARM_PID_FILE"
fi

echo "✅ All 14 elevator processes running in background. Telemetry piping to logs/"
echo "   Inspect: ps aux | grep yieldswarm   or   ./launch_swarm_elevators.sh status"

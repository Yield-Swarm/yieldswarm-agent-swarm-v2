#!/usr/bin/env bash
# =============================================================================
# Beta Swarm (Y-Axis / E¹) — hardware guard + continuous flow telemetry loop.
#
# Wraps deploy/entrypoint.monitor.sh with nvidia-smi fallback, PoW solenoid tick,
# and workload shedding when OmniDimensionalSafetyCanopy thresholds breach.
#
# Usage:
#   ./scripts/hardware-guard.sh [start|stop|status]
#   ./scripts/hardware-guard.sh start --workload-pid <pid>
#
# Environment:
#   VRAM_MAX_BYTES=31677329408   (~29.5 GiB)
#   TEMP_THRESHOLD_CELSIUS=83
#   API_BASE=http://127.0.0.1:8080
#   METRICS_URL=http://127.0.0.1:8000/metrics
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ACTION="${1:-start}"
shift || true
WORKLOAD_PID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workload-pid) WORKLOAD_PID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

RUN_DIR="${REPO_ROOT}/.run"
PID_FILE="${RUN_DIR}/hardware-guard.pid"
LOG_FILE="${RUN_DIR}/hardware-guard.log"
MONITOR="${REPO_ROOT}/deploy/entrypoint.monitor.sh"

mkdir -p "$RUN_DIR"

nvidia_fallback_metrics() {
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    return 1
  fi
  local line
  line="$(nvidia-smi --query-gpu=temperature.gpu,memory.used --format=csv,noheader,nounits | head -1)"
  local temp_mib
  temp_mib="$(echo "$line" | cut -d',' -f1 | tr -d ' ')"
  local mem_mib
  mem_mib="$(echo "$line" | cut -d',' -f2 | tr -d ' ')"
  local vram_bytes=$((mem_mib * 1024 * 1024))
  echo "gpu_temperature_celsius ${temp_mib}"
  echo "vram_allocated_bytes ${vram_bytes}"
}

start_guard() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[hardware-guard] already running (pid $(cat "$PID_FILE"))"
    return 0
  fi

  (
    export API_BASE="${API_BASE:-http://127.0.0.1:8080}"
    export METRICS_URL="${METRICS_URL:-http://127.0.0.1:8000/metrics}"
    export VRAM_MAX_BYTES="${VRAM_MAX_BYTES:-31677329408}"
    export TEMP_THRESHOLD_CELSIUS="${TEMP_THRESHOLD_CELSIUS:-83}"

    echo "[hardware-guard] E¹ flow loop started $(date -u +%Y-%m-%dT%H:%M:%SZ)"

    if [[ -x "$MONITOR" ]]; then
      if ! curl -sf "${METRICS_URL}" >/dev/null 2>&1; then
        echo "[hardware-guard] metrics endpoint down — nvidia-smi fallback active"
        while true; do
          metrics="$(nvidia_fallback_metrics || true)"
          if [[ -n "$metrics" ]]; then
            gpu_temp="$(echo "$metrics" | grep gpu_temperature | awk '{print $2}')"
            vram_used="$(echo "$metrics" | grep vram_allocated | awk '{print $2}')"
            if (( gpu_temp > TEMP_THRESHOLD_CELSIUS )); then
              curl -sf -X POST "${API_BASE}/api/solenoid/throttle" \
                -H 'Content-Type: application/json' \
                -d "{\"status\":\"THERMAL_LIMIT_EXCEEDED\",\"temp\":${gpu_temp}}" || true
              [[ -n "$WORKLOAD_PID" ]] && kill -USR1 "$WORKLOAD_PID" 2>/dev/null || true
            fi
            if (( vram_used > VRAM_MAX_BYTES )); then
              curl -sf -X POST "${API_BASE}/api/context/prune" \
                -H 'Content-Type: application/json' \
                -d '{"force":true}' || true
            fi
          fi
          node -e "
            const { MultiLingualSolenoidEngine } = require('./src/infrastructure/entropy-core');
            const e = new MultiLingualSolenoidEngine();
            e.incrementSolenoidLoop();
          " 2>/dev/null || true
          sleep "${POLL_INTERVAL_SECONDS:-2}"
        done
      else
        exec "$MONITOR"
      fi
    else
      echo "[hardware-guard] ERROR: $MONITOR not found" >&2
      exit 1
    fi
  ) >>"$LOG_FILE" 2>&1 &

  echo $! >"$PID_FILE"
  echo "[hardware-guard] started pid=$(cat "$PID_FILE") log=$LOG_FILE"
}

stop_guard() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill "$(cat "$PID_FILE")" && rm -f "$PID_FILE"
    echo "[hardware-guard] stopped"
  else
    echo "[hardware-guard] not running"
    rm -f "$PID_FILE"
  fi
}

status_guard() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[hardware-guard] running pid=$(cat "$PID_FILE")"
    tail -3 "$LOG_FILE" 2>/dev/null || true
  else
    echo "[hardware-guard] stopped"
  fi
}

case "$ACTION" in
  start) start_guard ;;
  stop) stop_guard ;;
  status) status_guard ;;
  *)
    echo "Usage: $0 {start|stop|status} [--workload-pid PID]" >&2
    exit 1
    ;;
esac

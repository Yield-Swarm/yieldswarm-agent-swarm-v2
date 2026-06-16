#!/usr/bin/env bash
# deploy/entrypoint.monitor.sh — GPU monitor with hard thermal (83°C) + VRAM (29.5GB) limits
# D¹ Mayhem Mode — zero-trust resource enforcement for RTX 5090 / H100 clusters
set -Eeuo pipefail

THERMAL_LIMIT_C="${THERMAL_LIMIT_C:-83}"
VRAM_MAX_GB="${VRAM_MAX_GB:-29.5}"
VRAM_TOTAL_GB="${VRAM_TOTAL_GB:-32}"
POLL_INTERVAL="${MONITOR_POLL_INTERVAL:-10}"
METRICS_PORT="${METRICS_PORT:-9091}"
ACTION_ON_BREACH="${ACTION_ON_BREACH:-throttle}" # throttle | pause | exit

log() { echo "[$(date -u +%FT%TZ)] [monitor] $*" >&2; }

read_gpu_stats() {
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "0 0 0"
    return
  fi
  nvidia-smi --query-gpu=temperature.gpu,memory.used,memory.total \
    --format=csv,noheader,nounits 2>/dev/null | head -1 | tr ',' ' '
}

vram_gb() {
  local used_mb="${1:-0}"
  awk -v u="$used_mb" 'BEGIN { printf "%.2f", u / 1024 }'
}

thermal_breach() {
  local temp="${1:-0}"
  [[ "${temp%%.*}" -gt "$THERMAL_LIMIT_C" ]]
}

vram_breach() {
  local used_mb="${1:-0}"
  local used_gb
  used_gb="$(vram_gb "$used_mb")"
  awk -v u="$used_gb" -v m="$VRAM_MAX_GB" 'BEGIN { exit (u > m) ? 0 : 1 }'
}

apply_breach_action() {
  local reason="$1"
  log "BREACH: $reason — action=$ACTION_ON_BREACH"
  case "$ACTION_ON_BREACH" in
    exit)
      log "Exiting monitor loop (hard stop)"
      exit 1
      ;;
    pause)
      log "Pausing workloads — touch /tmp/yieldswarm-monitor-pause"
      touch /tmp/yieldswarm-monitor-pause 2>/dev/null || true
      sleep 30
      rm -f /tmp/yieldswarm-monitor-pause 2>/dev/null || true
      ;;
    throttle|*)
      log "Throttling — reducing inference concurrency signal"
      echo "throttle" > /tmp/yieldswarm-monitor-state 2>/dev/null || true
      sleep 15
      echo "normal" > /tmp/yieldswarm-monitor-state 2>/dev/null || true
      ;;
  esac
}

start_metrics_exporter() {
  python3 - <<PY &
import os, time, subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(os.environ.get("METRICS_PORT", "9091"))
state = {"temp_c": 0, "vram_gb": 0, "vram_max_gb": float(os.environ.get("VRAM_MAX_GB", "29.5")), "breaches": 0}

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/healthz", "/health"):
            code = 503 if state["temp_c"] > float(os.environ.get("THERMAL_LIMIT_C", "83")) else 200
            self.send_response(code)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok" if code == 200 else b"thermal_breach")
            return
        if self.path == "/metrics":
            body = (
                f'yieldswarm_gpu_temp_c {state["temp_c"]}\n'
                f'yieldswarm_vram_used_gb {state["vram_gb"]}\n'
                f'yieldswarm_vram_max_gb {state["vram_max_gb"]}\n'
                f'yieldswarm_monitor_breaches_total {state["breaches"]}\n'
            )
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(body.encode())
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, *args): pass

def poll():
    while True:
        try:
            out = subprocess.check_output(
                ["nvidia-smi", "--query-gpu=temperature.gpu,memory.used", "--format=csv,noheader,nounits"],
                text=True,
            ).strip().split("\n")[0]
            t, used = out.split(", ")
            state["temp_c"] = float(t.strip())
            state["vram_gb"] = float(used.strip()) / 1024.0
        except Exception:
            pass
        time.sleep(int(os.environ.get("MONITOR_POLL_INTERVAL", "10")))

import threading
threading.Thread(target=poll, daemon=True).start()
HTTPServer(("0.0.0.0", port), H).serve_forever()
PY
  log "Metrics on :${METRICS_PORT} (/healthz, /metrics)"
}

monitor_loop() {
  log "Monitor live — thermal<=${THERMAL_LIMIT_C}C vram<=${VRAM_MAX_GB}GB (total ${VRAM_TOTAL_GB}GB)"
  while true; do
    read -r temp used_mb total_mb <<< "$(read_gpu_stats)"
    temp="${temp// /}"
    used_mb="${used_mb// /}"
    used_gb="$(vram_gb "${used_mb:-0}")"

    if thermal_breach "${temp:-0}"; then
      apply_breach_action "GPU temp ${temp}C > ${THERMAL_LIMIT_C}C"
    elif vram_breach "${used_mb:-0}"; then
      apply_breach_action "VRAM ${used_gb}GB > ${VRAM_MAX_GB}GB"
    fi

    sleep "$POLL_INTERVAL"
  done
}

main() {
  start_metrics_exporter
  monitor_loop
}

main "$@"

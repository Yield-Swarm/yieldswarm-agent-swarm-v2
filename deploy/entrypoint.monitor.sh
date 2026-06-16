#!/usr/bin/env bash
# =============================================================================
# deploy/entrypoint.monitor.sh — Greek layer ($D^1$) hardware guardrail monitor.
#
# Enforces hard ceilings on GPU VRAM (29.5 GB) and temperature (83°C).
# When thresholds are breached, triggers automated context pruning via SIGUSR1
# to the workload process and logs an append-only audit event.
#
# Usage:
#   entrypoint.monitor.sh <workload-pid> [poll-interval-seconds]
# Environment:
#   VRAM_CEILING_GB=29.5
#   TEMP_CEILING_C=83
#   PRUNE_SCRIPT=deploy/scripts/prune-context.sh
#   AUDIT_LOG=.run/hardware-audit.log
# =============================================================================
set -euo pipefail

WORKLOAD_PID="${1:?workload pid required}"
POLL_INTERVAL="${2:-5}"

VRAM_CEILING_GB="${VRAM_CEILING_GB:-29.5}"
TEMP_CEILING_C="${TEMP_CEILING_C:-83}"
PRUNE_SCRIPT="${PRUNE_SCRIPT:-$(dirname "$0")/scripts/prune-context.sh}"
AUDIT_LOG="${AUDIT_LOG:-.run/hardware-audit.log}"

log()  { printf '[monitor] %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
die()  { log "FATAL: $*"; exit 1; }

mkdir -p "$(dirname "$AUDIT_LOG")"

audit_event() {
  local event="$1"
  local detail="$2"
  printf '{"ts":"%s","event":"%s","detail":%s,"pid":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "$detail" "$WORKLOAD_PID" >> "$AUDIT_LOG"
}

bytes_to_gb() {
  awk -v b="$1" 'BEGIN { printf "%.3f", b / 1024 / 1024 / 1024 }'
}

read_gpu_metrics() {
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "NO_GPU"
    return
  fi
  nvidia-smi --query-gpu=memory.used,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1
}

trigger_prune() {
  local reason="$1"
  log "THRESHOLD BREACH — $reason — triggering context prune"
  audit_event "context_prune" "$(printf '{"reason":"%s"}' "$reason")"

  if [[ -x "$PRUNE_SCRIPT" ]]; then
    bash "$PRUNE_SCRIPT" "$WORKLOAD_PID" "$reason" || log "prune script returned non-zero"
  elif kill -0 "$WORKLOAD_PID" 2>/dev/null; then
    kill -USR1 "$WORKLOAD_PID" 2>/dev/null || log "SIGUSR1 not handled by workload"
  else
    log "workload pid $WORKLOAD_PID not running"
  fi
}

kill -0 "$WORKLOAD_PID" 2>/dev/null || die "workload pid $WORKLOAD_PID not found"

log "monitoring pid=$WORKLOAD_PID vram_ceiling=${VRAM_CEILING_GB}GB temp_ceiling=${TEMP_CEILING_C}C interval=${POLL_INTERVAL}s"
audit_event "monitor_start" "$(printf '{"vramGb":%s,"tempC":%s}' "$VRAM_CEILING_GB" "$TEMP_CEILING_C")"

while kill -0 "$WORKLOAD_PID" 2>/dev/null; do
  metrics="$(read_gpu_metrics)"

  if [[ "$metrics" == "NO_GPU" ]]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  mem_mib="$(echo "$metrics" | cut -d',' -f1 | tr -d ' ')"
  temp_c="$(echo "$metrics" | cut -d',' -f2 | tr -d ' ')"

  mem_bytes=$((mem_mib * 1024 * 1024))
  mem_gb="$(bytes_to_gb "$mem_bytes")"

  vram_breach="$(awk -v u="$mem_gb" -v c="$VRAM_CEILING_GB" 'BEGIN { print (u > c) ? 1 : 0 }')"
  temp_breach="$(awk -v t="$temp_c" -v c="$TEMP_CEILING_C" 'BEGIN { print (t > c) ? 1 : 0 }')"

  if [[ "$vram_breach" == "1" ]]; then
    trigger_prune "vram ${mem_gb}GB > ${VRAM_CEILING_GB}GB"
  fi

  if [[ "$temp_breach" == "1" ]]; then
    trigger_prune "temperature ${temp_c}C > ${TEMP_CEILING_C}C"
  fi

  sleep "$POLL_INTERVAL"
done

log "workload exited — monitor stopping"
audit_event "monitor_stop" '{"reason":"workload_exit"}'

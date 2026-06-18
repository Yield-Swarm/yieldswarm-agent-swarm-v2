#!/usr/bin/env bash
# deploy/openclaw/entrypoint.mining.sh
# Dual mining: XMRig (CPU) + GPU miner (Kaspa/Bittensor) + thermal guard + Helix telemetry.
set -euo pipefail

APP_ROOT="${APP_ROOT:-/app}"
RUN_DIR="${RUN_DIR:-/run/mining}"
METRICS_FILE="${RUN_DIR}/metrics.jsonl"
PID_DIR="${RUN_DIR}/pids"

mkdir -p "$RUN_DIR" "$PID_DIR"

# --- env (never hardcode secrets) ---
MINING_ENABLED="${MINING_ENABLED:-1}"
MINING_CPU_COIN="${MINING_CPU_COIN:-xmr}"
MINING_GPU_COIN="${MINING_GPU_COIN:-kaspa}"
XMR_POOL_URL="${XMR_POOL_URL:-}"
XMR_WALLET="${XMR_WALLET:-}"
XMRIG_THREADS="${XMRIG_THREADS:-0}"
GPU_MINER_BIN="${GPU_MINER_BIN:-/opt/gpu-miner/miner}"
KASPA_POOL_URL="${KASPA_POOL_URL:-}"
KASPA_WALLET="${KASPA_WALLET:-}"
BT_NETUID="${BT_NETUID:-1}"
TEMP_CEILING_C="${TEMP_CEILING_C:-83}"
VRAM_CEILING_GB="${VRAM_CEILING_GB:-29.5}"
TELEMETRY_INTERVAL_SEC="${TELEMETRY_INTERVAL_SEC:-30}"
MINING_TELEMETRY_URL="${MINING_TELEMETRY_URL:-http://127.0.0.1:8080/api/mining/telemetry}"
TOS_ALLOWED_PROVIDERS="${TOS_ALLOWED_PROVIDERS:-vast,runpod,akash,cherry}"
CLOUD_PROVIDER="${CLOUD_PROVIDER:-unknown}"
INSTANCE_ID="${INSTANCE_ID:-$(hostname)}"
OPENCLAW_INSTANCE_INDEX="${OPENCLAW_INSTANCE_INDEX:-0}"

log() { printf '[openclaw-mining] %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

provider_ok() {
  local p="${CLOUD_PROVIDER,,}"
  IFS=',' read -ra allowed <<< "$TOS_ALLOWED_PROVIDERS"
  for a in "${allowed[@]}"; do
    [[ "${a,,}" == "$p" ]] && return 0
  done
  log "WARN: provider '$CLOUD_PROVIDER' not in TOS_ALLOWED_PROVIDERS — mining disabled"
  return 1
}

write_health() {
  cat >"${RUN_DIR}/health.json" <<EOF
{"status":"ok","instance":"${INSTANCE_ID}","provider":"${CLOUD_PROVIDER}","cpu":"${MINING_CPU_COIN}","gpu":"${MINING_GPU_COIN}"}
EOF
  python3 -m http.server 8080 --directory "$RUN_DIR" >/dev/null 2>&1 &
  echo $! >"${PID_DIR}/health.pid"
}

start_xmrig() {
  [[ "$MINING_ENABLED" == "1" ]] || return 0
  [[ -n "$XMR_POOL_URL" && -n "$XMR_WALLET" ]] || { log "XMR pool/wallet unset — skip CPU miner"; return 0; }
  local threads="$XMRIG_THREADS"
  if [[ "$threads" == "0" ]]; then
    threads="$(nproc 2>/dev/null || echo 4)"
  fi
  log "starting XMRig threads=$threads pool=$XMR_POOL_URL"
  /opt/xmrig/xmrig \
    --url="$XMR_POOL_URL" \
    --user="$XMR_WALLET" \
    --threads="$threads" \
    --donate-level=1 \
    --background \
    --log-file="${RUN_DIR}/xmrig.log"
  pgrep -f xmrig | head -1 >"${PID_DIR}/xmrig.pid" || true
}

start_gpu_miner() {
  [[ "$MINING_ENABLED" == "1" ]] || return 0
  case "${MINING_GPU_COIN,,}" in
    kaspa)
      if [[ -x "$GPU_MINER_BIN" && -n "$KASPA_POOL_URL" && -n "$KASPA_WALLET" ]]; then
        log "starting GPU Kaspa miner"
        "$GPU_MINER_BIN" --pool "$KASPA_POOL_URL" --wallet "$KASPA_WALLET" \
          >>"${RUN_DIR}/gpu-miner.log" 2>&1 &
        echo $! >"${PID_DIR}/gpu.pid"
      else
        log "GPU miner binary or Kaspa creds missing — skip (mount lolminer to $GPU_MINER_BIN)"
      fi
      ;;
    bittensor)
      if command -v btcli >/dev/null 2>&1; then
        log "starting Bittensor miner netuid=$BT_NETUID"
        btcli mine start --netuid "$BT_NETUID" >>"${RUN_DIR}/bt.log" 2>&1 &
        echo $! >"${PID_DIR}/bt.pid"
      else
        log "btcli not installed — use bittensor miner image for GPU subnet"
      fi
      ;;
    none|skip) log "GPU mining disabled" ;;
    *) log "unknown MINING_GPU_COIN=$MINING_GPU_COIN" ;;
  esac
}

read_gpu_metrics() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=memory.used,temperature.gpu,utilization.gpu,power.draw \
      --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '
  else
    echo "0,0,0,0"
  fi
}

thermal_guard() {
  local line mem_mib temp_c util_pct power_w vram_gb
  line="$(read_gpu_metrics)"
  IFS=',' read -r mem_mib temp_c util_pct power_w <<< "$line"
  local vram_gb
  vram_gb="$(awk -v m="${mem_mib:-0}" 'BEGIN { printf "%.2f", m/1024 }')"
  if [[ "${temp_c:-0}" -ge "$TEMP_CEILING_C" ]] 2>/dev/null; then
    log "THERMAL GUARD: ${temp_c}C >= ${TEMP_CEILING_C}C — throttling miners"
    for f in xmrig gpu bt; do
      [[ -f "${PID_DIR}/${f}.pid" ]] && kill -STOP "$(cat "${PID_DIR}/${f}.pid")" 2>/dev/null || true
    done
    curl -sf -X POST "${MINING_TELEMETRY_URL%/telemetry}/throttle" \
      -H 'Content-Type: application/json' \
      -d "{\"temp\":${temp_c},\"status\":\"THERMAL_LIMIT\"}" 2>/dev/null || true
    sleep 30
    for f in xmrig gpu bt; do
      [[ -f "${PID_DIR}/${f}.pid" ]] && kill -CONT "$(cat "${PID_DIR}/${f}.pid")" 2>/dev/null || true
    done
  fi
  if awk -v v="$vram_gb" -v c="$VRAM_CEILING_GB" 'BEGIN { exit !(v > c) }' 2>/dev/null; then
    log "VRAM GUARD: ${vram_gb}GB > ${VRAM_CEILING_GB}GB"
  fi
  echo "$vram_gb,$temp_c,$util_pct,$power_w"
}

telemetry_pulse() {
  local gpu_line="$1"
  local mem_mib temp_c util_pct power_w vram_gb
  IFS=',' read -r vram_gb temp_c util_pct power_w <<< "$gpu_line"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local payload
  payload=$(jq -nc \
    --arg inst "$INSTANCE_ID" \
    --arg prov "$CLOUD_PROVIDER" \
    --arg cpu "$MINING_CPU_COIN" \
    --arg gpu "$MINING_GPU_COIN" \
    --argjson idx "${OPENCLAW_INSTANCE_INDEX:-0}" \
    --argjson vram "${vram_gb:-0}" \
    --argjson temp "${temp_c:-0}" \
    --argjson util "${util_pct:-0}" \
    --argjson power "${power_w:-0}" \
    --arg ts "$ts" \
    '{source:"openclaw-mining",instanceId:$inst,provider:$prov,cpuCoin:$cpu,gpuCoin:$gpu,instanceIndex:$idx,vramUsedGb:$vram,tempC:$temp,gpuUtilPct:$util,powerW:$power,creditBurnMode:true,ts:$ts}')

  echo "$payload" >>"$METRICS_FILE"
  curl -sf -X POST "$MINING_TELEMETRY_URL" \
    -H 'Content-Type: application/json' \
    -d "$payload" 2>/dev/null || log "telemetry POST failed (offline ingest OK via $METRICS_FILE)"

  if [[ -f "${APP_ROOT}/mining/telemetry-pulse.py" ]]; then
    python3 "${APP_ROOT}/mining/telemetry-pulse.py" <<<"$payload" 2>/dev/null || true
  fi
}

rollback() {
  log "ROLLBACK: stopping miners"
  for f in "${PID_DIR}"/*.pid; do
    [[ -f "$f" ]] && kill "$(cat "$f")" 2>/dev/null || true
  done
}
trap rollback EXIT INT TERM

# --- main ---
if ! provider_ok; then
  MINING_ENABLED=0
fi

write_health
start_xmrig
start_gpu_miner

# Hardware guard background (uses repo script when mounted)
if [[ -x "${APP_ROOT}/scripts/hardware-guard.sh" ]]; then
  "${APP_ROOT}/scripts/hardware-guard.sh" start --workload-pid "$$" &
fi

log "mining loop started instance=$INSTANCE_ID provider=$CLOUD_PROVIDER"
while true; do
  line="$(thermal_guard)"
  telemetry_pulse "$line"
  sleep "$TELEMETRY_INTERVAL_SEC"
done

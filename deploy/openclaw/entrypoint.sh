#!/usr/bin/env bash
# OpenClaw worker entrypoint — telemetry, thermal guard, workload mode dispatch.
set -euo pipefail

WORKLOAD_MODE="${WORKLOAD_MODE:-openclaw}"
API_BASE="${API_BASE:-http://127.0.0.1:8080}"
TEMP_THRESHOLD_CELSIUS="${TEMP_THRESHOLD_CELSIUS:-83}"
INSTANCE_ID="${OPENCLAW_INSTANCE_ID:-${HOSTNAME:-openclaw-1}}"

echo "=== YieldSwarm OpenClaw Worker ==="
echo "    instance=$INSTANCE_ID mode=$WORKLOAD_MODE api=$API_BASE"

# Background hardware guardian (83°C thermal shed → solenoid API)
if [[ -f /app/deploy/entrypoint.monitor.sh ]]; then
  API_BASE="$API_BASE" TEMP_THRESHOLD_CELSIUS="$TEMP_THRESHOLD_CELSIUS" \
    bash /app/deploy/entrypoint.monitor.sh &
fi

pulse_telemetry() {
  local temp="${GPU_TEMP:-72}"
  local vram="${VRAM_BYTES:-0}"
  curl -sf -X POST "${API_BASE}/api/telemetry/pulse" \
    -H "Content-Type: application/json" \
    -d "{\"pillarId\":5,\"name\":\"05_arena_leaderboard\",\"metrics\":{\"gpu_temperature\":${temp},\"vram_used_bytes\":${vram},\"worker_id\":\"${INSTANCE_ID}\"}}" \
    2>/dev/null || true
}

run_openclaw_scaler() {
  if [[ -f /app/agents/openclaw-scaler.py ]]; then
    cd /app && python3 agents/openclaw-scaler.py || true
  fi
}

run_dual_yield() {
  echo "[dual-yield] GPU track: bittensor | CPU track: grass/depin"
  echo "  SDL: deploy/akash-bittensor-miner.sdl.yml (GPU)"
  echo "  POW_MINING_COINS=${POW_MINING_COINS:-bittensor,grass}"
  run_openclaw_scaler
}

run_pow_dual() {
  echo "[pow-dual] Operator-enabled external mining mode"
  echo "  WARNING: verify provider ToS. Official image does not ship XMRig/KAS miners."
  echo "  Mount operator configs to /app/config/ or use custom image."
  if [[ -f /app/config/xmrig.json ]]; then
    echo "  Found xmrig.json — operator-managed miner (not started by default image)"
  fi
}

case "$WORKLOAD_MODE" in
  openclaw) run_openclaw_scaler ;;
  dual-yield) run_dual_yield ;;
  pow-dual) run_pow_dual ;;
  *) echo "Unknown WORKLOAD_MODE=$WORKLOAD_MODE"; exit 1 ;;
esac

pulse_telemetry

# Heartbeat loop
while true; do
  sleep "${HEARTBEAT_INTERVAL_SECONDS:-420}"
  pulse_telemetry
  echo "[$(date -Iseconds)] openclaw heartbeat instance=$INSTANCE_ID mode=$WORKLOAD_MODE"
done

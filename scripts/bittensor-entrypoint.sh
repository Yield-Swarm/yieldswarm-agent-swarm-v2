#!/usr/bin/env bash
# Akash entrypoint: Kairo API + worker telemetry; optional Bittensor miner loop.
set -euo pipefail

cd /app
export PYTHONPATH="/app:/app/kairo:${PYTHONPATH:-}"

KAIRO_PORT="${KAIRO_API_PORT:-8091}"
WORKER_PORT="${WORKER_PORT:-8080}"

log() { echo "[bittensor-worker] $*"; }

start_kairo() {
  log "starting Kairo API on :${KAIRO_PORT}"
  python -m kairo.api.routes &
  KAIRO_PID=$!
}

start_worker() {
  log "starting telemetry worker on :${WORKER_PORT}"
  export PORT="${WORKER_PORT}"
  python /app/deploy/runtime/worker.py &
  WORKER_PID=$!
}

start_bittensor() {
  if [[ -z "${BITTENSOR_MINER_COLDKEY_HEX:-}" ]]; then
    log "BITTENSOR_MINER_COLDKEY_HEX unset — skipping miner (inject from Vault)"
    return 0
  fi
  if ! python -c "import bittensor" 2>/dev/null; then
    log "bittensor package not installed — skipping miner subprocess"
    return 0
  fi
  log "starting Bittensor miner netuid=${BT_NETUID:-1} network=${BT_NETWORK:-finney}"
  python - <<'PY' &
import os
import time

netuid = int(os.getenv("BT_NETUID", "1"))
network = os.getenv("BT_NETWORK", "finney")
print(f"[bittensor] miner stub active netuid={netuid} network={network}", flush=True)
while True:
    time.sleep(60)
    print("[bittensor] heartbeat", flush=True)
PY
  BT_PID=$!
}

trap 'log "shutting down"; kill ${KAIRO_PID:-} ${WORKER_PID:-} ${BT_PID:-} 2>/dev/null || true' TERM INT

start_kairo
start_worker
start_bittensor

wait -n ${KAIRO_PID} ${WORKER_PID} 2>/dev/null || wait

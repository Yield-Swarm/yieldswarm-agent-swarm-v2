#!/usr/bin/env bash
# ==============================================================================
# Poseidon Delta Trident — Termux + Akash + Own Hardware Deploy (v4.1.0)
# ==============================================================================
# Replaces the legacy v4.0 manifest that patched node_modules and overwrote
# next.config.js. This script uses repo conventions:
#   - Backend API on :8080 (Termux-safe)
#   - Optional xmrig mining via scripts/mining/tandem-pow-launch.sh
#   - Optional Akash SDL deploy via scripts/deploy-backend-akash.sh
#   - No node_modules sed hacks; next.config.mjs is never touched
#
# Usage (on phone or edge box):
#   cd $HOME/yieldswarm-agent-swarm-v2
#   cp deploy/env/trident-mainnet.env.example deploy/env/trident-mainnet.env
#   # edit wallets + AKASH_KEY_NAME
#   bash scripts/termux/poseidon-deploy.sh
#
# Modes (POSEIDON_MODE):
#   edge   — backend + mining + consensus (default on Termux)
#   full   — edge + Next.js dev (proot Ubuntu / desktop only)
#   akash  — trigger Akash backend SDL deploy only
#   all    — edge + Akash trigger (no blocking wait on lease)
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

log() { printf '[poseidon] %s\n' "$*" >&2; }

# --- Load environment ---
mkdir -p deploy/env reports .run
if [[ ! -f deploy/env/trident-mainnet.env ]]; then
  cp deploy/env/trident-mainnet.env.example deploy/env/trident-mainnet.env
  log "Created deploy/env/trident-mainnet.env — edit wallets before mainnet mining."
fi
set -a
# shellcheck disable=SC1091
source deploy/env/trident-mainnet.env
[[ -f .env ]] && source .env
set +a

HOST_KIND="$(bash scripts/termux/detect-host.sh)"
export MINING_NODE_ID="${MINING_NODE_ID:-Arena_Agentic_Pod_$(shuf -i 1000-9999 -n 1 2>/dev/null || date +%s)}"
export POSEIDON_MODE="${POSEIDON_MODE:-edge}"
export PORT="${PORT:-8080}"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=2048}"

log "Host: $HOST_KIND | Mode: $POSEIDON_MODE | Node: $MINING_NODE_ID | Port: $PORT"

# --- Optional stale port release (scoped, not nuclear pkill) ---
release_port() {
  local port="$1"
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${port}/tcp" 2>/dev/null || true
  elif command -v lsof >/dev/null 2>&1; then
    lsof -ti:"$port" | xargs -r kill 2>/dev/null || true
  fi
}
if [[ "${POSEIDON_KILL_PORTS:-1}" == "1" ]]; then
  log "Releasing ports $PORT and ${NEXT_PORT:-3000}..."
  release_port "$PORT"
  release_port "${NEXT_PORT:-3000}"
fi

# --- Dependencies (skip if node_modules present) ---
if [[ ! -d node_modules ]] || [[ "${POSEIDON_FORCE_INSTALL:-0}" == "1" ]]; then
  log "Installing npm dependencies..."
  npm ci --omit=dev 2>/dev/null || npm install --omit=dev
fi
if [[ ! -d backend/node_modules ]]; then
  log "Installing backend dependencies..."
  (cd backend && npm ci 2>/dev/null || npm install)
fi

# --- Akash cloud slice (non-blocking unless POSEIDON_AKASH_WAIT=1) ---
deploy_akash() {
  if [[ -z "${AKASH_KEY_NAME:-}" ]]; then
    log "Akash skip — set AKASH_KEY_NAME in deploy/env/trident-mainnet.env"
    return 0
  fi
  if ! command -v provider-services >/dev/null 2>&1; then
    log "Akash skip — provider-services CLI not installed (see docs/AKASH_DEPLOY.md)"
    return 0
  fi
  log "Triggering Akash backend SDL deploy..."
  if [[ -x scripts/akash-preflight.sh ]]; then
    bash scripts/akash-preflight.sh || log "Akash preflight warnings — continuing"
  fi
  if [[ "${POSEIDON_AKASH_WAIT:-0}" == "1" ]]; then
    bash scripts/deploy-backend-akash.sh
  else
    nohup bash scripts/deploy-backend-akash.sh > .run/akash-deploy.log 2>&1 &
    log "Akash deploy running in background — tail .run/akash-deploy.log"
  fi
}

# --- Local edge: integration backend ---
start_backend() {
  log "Starting integration backend on :$PORT ..."
  export PORT
  nohup npm run prod:backend > .run/backend.log 2>&1 &
  echo $! > .run/backend.pid
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
      log "Backend healthy at http://127.0.0.1:${PORT}/api/health"
      return 0
    fi
    sleep 1
  done
  log "WARN: backend health check timed out — see .run/backend.log"
}

# --- Own hardware mining (xmrig via tandem launcher) ---
start_mining() {
  if [[ "${MINING_DRY_RUN:-1}" == "1" ]]; then
    log "Mining dry-run — set MINING_DRY_RUN=0 and wallets to enable xmrig"
    return 0
  fi
  log "Launching tandem PoW miner (background)..."
  nohup bash scripts/mining/tandem-pow-launch.sh > .run/mining.log 2>&1 &
  echo $! > .run/mining.pid
}

# --- Vehicle DePIN edge (optional) ---
start_vehicle_edge() {
  if [[ ! -f services/depin/vehicle-edge.mjs ]]; then
    return 0
  fi
  if [[ -z "${VEHICLE_ID:-}" ]]; then
    return 0
  fi
  log "Starting vehicle DePIN edge for ${VEHICLE_ID}..."
  nohup node services/depin/vehicle-edge.mjs > .run/vehicle-edge.log 2>&1 &
  echo $! > .run/vehicle-edge.pid
}

# --- Consensus audit (non-fatal) ---
run_consensus() {
  if [[ "${POSEIDON_SKIP_CONSENSUS:-0}" == "1" ]]; then
    return 0
  fi
  bash scripts/termux/run-consensus-audit.sh || log "Consensus audit finished with warnings"
}

# --- Next.js dashboard (proot / desktop only) ---
start_next_dev() {
  if [[ "$HOST_KIND" == "termux-android" ]]; then
    log "Skipping Next.js on raw Termux — use proot Ubuntu or HP/desktop for dashboard"
    return 0
  fi
  log "Starting Next.js dev (webpack) on :${NEXT_PORT:-3000}..."
  export NEXT_PORT="${NEXT_PORT:-3000}"
  nohup bash scripts/termux/launch-openclaws-dev.sh > .run/next-dev.log 2>&1 &
  echo $! > .run/next-dev.pid
}

# --- Execute mode matrix ---
case "$POSEIDON_MODE" in
  akash)
    deploy_akash
    ;;
  edge)
    start_backend
    start_mining
    start_vehicle_edge
    run_consensus
    ;;
  full)
    start_backend
    start_mining
    start_vehicle_edge
    run_consensus
    start_next_dev
    ;;
  all)
    start_backend
    start_mining
    start_vehicle_edge
    deploy_akash
    run_consensus
    ;;
  *)
    log "Unknown POSEIDON_MODE=$POSEIDON_MODE — use edge|full|akash|all"
    exit 1
    ;;
esac

echo "====================================================================="
echo "STATUS: POSEIDON POD ARMED"
echo "Host:        $HOST_KIND"
echo "Mode:        $POSEIDON_MODE"
echo "Node ID:     $MINING_NODE_ID"
echo "Backend:     http://127.0.0.1:${PORT}/api/health"
echo "Bridge API:  http://127.0.0.1:${PORT}/api/trident/marketplace-bridge"
echo "Arena:       http://127.0.0.1:${PORT}/api/arena/overview"
echo "Logs:        .run/backend.log  .run/mining.log  .run/akash-deploy.log"
echo "====================================================================="

# Foreground tail when launched interactively (Ctrl+C stops tail only)
if [[ -t 1 && "${POSEIDON_FOREGROUND:-1}" == "1" && "$POSEIDON_MODE" != "akash" ]]; then
  log "Tailing backend log (Ctrl+C to detach)..."
  tail -f .run/backend.log
fi

#!/usr/bin/env bash
# start-mining.sh — one-command Akash Bittensor miner deploy (Termux / Azure / local).
#
# Uses canonical repo assets (do NOT hand-edit SDL):
#   deploy/akash-bittensor-miner.sdl.yml
#   scripts/deploy-bittensor.sh → scripts/deploy-to-akash.sh
#
# Setup:
#   cp deploy/akash.env.example deploy/akash.env
#   # edit deploy/akash.env — wallet, BT_NETUID, Vault
#   ./scripts/akash-preflight.sh deploy/akash-bittensor-miner.sdl.yml
#
# Usage:
#   ./scripts/start-mining.sh              # deploy Bittensor miner SDL
#   ./scripts/start-mining.sh preflight    # GO/NO-GO only
#   ./scripts/start-mining.sh monolith     # 3× RTX 3090 swarm monolith SDL
#   MINING_DRY_RUN=1 ./scripts/start-mining.sh   # config check only
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MODE="${1:-bittensor}"
SDL_BITTENSOR="deploy/akash-bittensor-miner.sdl.yml"
SDL_MONOLITH="deploy/deploy-swarm-monolith.yaml"

load_env() {
  local f
  for f in deploy/akash.env deploy/config.env .env; do
    [[ -f "$f" ]] || continue
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
  done
}

load_env

export BT_NETUID="${BT_NETUID:-1}"
export BT_NETWORK="${BT_NETWORK:-finney}"
export BT_WALLET_NAME="${BT_WALLET_NAME:-miner}"
export BT_HOTKEY_NAME="${BT_HOTKEY_NAME:-default}"
export AKASH_SDL="${AKASH_SDL:-$SDL_BITTENSOR}"
export DEPLOY_SDL="${DEPLOY_SDL:-$SDL_BITTENSOR}"

echo "=== YieldSwarm Akash mining ==="
echo "Repo: ${REPO_ROOT}"
echo "Mode: ${MODE}"
echo "SDL:  ${DEPLOY_SDL}"

case "$MODE" in
  preflight|check)
    exec ./scripts/akash-preflight.sh "${DEPLOY_SDL}"
    ;;
esac

if [[ "${MINING_DRY_RUN:-0}" == "1" ]]; then
  echo "[dry-run] Skipping live deploy."
  ./scripts/akash-preflight.sh "${DEPLOY_SDL}" || true
  ./scripts/mining/mining-manager.sh config
  exit 0
fi

case "$MODE" in
  monolith|swarm)
    export DEPLOY_SDL="$SDL_MONOLITH"
    export AKASH_SDL="$SDL_MONOLITH"
    ./scripts/akash-preflight.sh "${SDL_MONOLITH}"
    exec ./scripts/deploy-to-akash.sh deploy "${SDL_MONOLITH}"
    ;;
  bittensor|miner|"")
    export DEPLOY_SDL="$SDL_BITTENSOR"
    export AKASH_SDL="$SDL_BITTENSOR"
    ./scripts/akash-preflight.sh "${SDL_BITTENSOR}"
    exec ./scripts/deploy-bittensor.sh
    ;;
  vault)
    export DEPLOY_SDL="${SDL_FILE:-$SDL_BITTENSOR}"
    export SDL_FILE="$DEPLOY_SDL"
    exec ./scripts/akash-deploy-with-vault.sh
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Usage: $0 [bittensor|monolith|preflight|vault]" >&2
    exit 1
    ;;
esac

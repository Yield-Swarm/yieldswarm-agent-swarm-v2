#!/usr/bin/env bash
# Production entrypoint: Ollama + telemetry (8080) + Bittensor axon (8091)
set -euo pipefail

log() { printf '[bittensor-entrypoint] %s\n' "$*" >&2; }

: "${BT_NETUID:?Set BT_NETUID}"
BT_NETWORK="${BT_NETWORK:-finney}"
BT_AXON_PORT="${BT_AXON_PORT:-8091}"
TELEMETRY_PORT="${TELEMETRY_PORT:-8080}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0:11434}"
BITTENSOR_STATUS_FILE="${BITTENSOR_STATUS_FILE:-/run/bittensor/status.json}"
BT_WALLET_PATH="${BT_WALLET_PATH:-/secrets/bittensor}"

export BT_NETUID BT_NETWORK BT_AXON_PORT TELEMETRY_PORT OLLAMA_MODEL BITTENSOR_STATUS_FILE

mkdir -p /run/bittensor "$(dirname "${BITTENSOR_STATUS_FILE}")"

# --- Optional Vault secret injection ---
if [[ -n "${VAULT_ADDR:-}" && -n "${VAULT_ROLE_ID:-}" && -n "${VAULT_SECRET_ID:-}" && -f /app/deploy/akash/entrypoint.sh ]]; then
  log "Injecting secrets from Vault"
  VAULT_SECRET_PATHS="${VAULT_SECRET_PATHS:-akash,bittensor,rpc}" \
  SECRETS_FILE="/run/secrets/app.env" \
    bash /app/deploy/akash/entrypoint.sh --inject-only || log "WARN: Vault injection skipped"
  if [[ -f /run/secrets/app.env ]]; then
    # shellcheck disable=SC1091
    set -a && source /run/secrets/app.env && set +a
  fi
fi

# --- Wallet setup ---
if [[ -d "${BT_WALLET_PATH}" ]]; then
  export BT_WALLET_DIR="${BT_WALLET_PATH}"
  log "Using wallet from ${BT_WALLET_PATH}"
elif [[ -n "${BITTENSOR_WALLET_JSON:-}" ]]; then
  mkdir -p "${BT_WALLET_PATH}"
  echo "${BITTENSOR_WALLET_JSON}" > "${BT_WALLET_PATH}/wallet.json"
  log "Wallet materialized from BITTENSOR_WALLET_JSON"
fi

# --- Ollama ---
log "Starting Ollama on ${OLLAMA_HOST}"
OLLAMA_HOST="${OLLAMA_HOST}" ollama serve &
OLLAMA_PID=$!
sleep 3

for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    log "Ollama ready"
    break
  fi
  sleep 2
done

log "Pulling model ${OLLAMA_MODEL}"
ollama pull "${OLLAMA_MODEL}" || log "WARN: model pull failed — may already exist"

# --- Telemetry server (port 8080) ---
log "Starting telemetry server on :${TELEMETRY_PORT}"
python3 /app/agents/bittensor_telemetry_server.py &
TELEMETRY_PID=$!

# --- Bittensor miner (port 8091) ---
log "Starting Bittensor miner netuid=${BT_NETUID} network=${BT_NETWORK} axon=${BT_AXON_PORT}"
python3 /app/agents/bittensor_miner.py &
MINER_PID=$!

trap 'kill ${MINER_PID} ${TELEMETRY_PID} ${OLLAMA_PID} 2>/dev/null || true' EXIT

# Wait for any process to exit
wait -n ${MINER_PID} ${TELEMETRY_PID} ${OLLAMA_PID}
exit $?

#!/usr/bin/env bash
# hotload-inference.sh — Single-pod Ollama serve + one primary model (RunPod)
#
# Realistic replacement for multi-screen ollama run loops that OOM GPUs.
#
# Usage:
#   export INFERENCE_MODEL=qwen2.5-coder:32b
#   ./scripts/runpod/hotload-inference.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${YIELDSWARM_LOG_DIR:-$HOME/yieldswarm-logs}"
BIND="${OLLAMA_BIND:-127.0.0.1}"
PORT="${OLLAMA_PORT:-11434}"
MODEL="${INFERENCE_MODEL:-qwen2.5-coder:32b}"
SESSION="${OLLAMA_SCREEN_SESSION:-ollama_backend}"

log() { printf '[inference] %s\n' "$*" >&2; }

mkdir -p "${LOG_DIR}"

log "pod inference bootstrap — model=${MODEL} bind=${BIND}:${PORT}"

# Stop stale processes (optional clean start)
pkill -f 'ollama serve' 2>/dev/null || true
sleep 1

if ! command -v ollama >/dev/null 2>&1; then
  log "installing ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
fi

export OLLAMA_HOST="${BIND}:${PORT}"

if command -v screen >/dev/null 2>&1; then
  screen -S "${SESSION}" -X quit 2>/dev/null || true
  screen -dmS "${SESSION}" bash -lc "OLLAMA_HOST=${OLLAMA_HOST} ollama serve"
  log "ollama serve in screen: ${SESSION}"
else
  log "starting ollama serve (foreground fallback)..."
  OLLAMA_HOST="${OLLAMA_HOST}" ollama serve >>"${LOG_DIR}/ollama.log" 2>&1 &
fi

log "waiting for API..."
for _ in $(seq 1 30); do
  if curl -sf "http://${OLLAMA_HOST}/api/tags" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

log "pulling model (may take several minutes)..."
ollama pull "${MODEL}" >>"${LOG_DIR}/ollama-pull.log" 2>&1

curl -sf "http://${OLLAMA_HOST}/api/tags" | python3 -m json.tool 2>/dev/null | head -20 || true

log "OK — endpoint http://${OLLAMA_HOST}/v1 (OpenAI compatible)"
log "test: curl http://${OLLAMA_HOST}/api/generate -d '{\"model\":\"${MODEL}\",\"prompt\":\"ping\",\"stream\":false}'"

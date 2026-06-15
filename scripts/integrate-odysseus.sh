#!/usr/bin/env bash
# Wire Odysseus to Akash RTX 3090 workers, external LLM providers, and ChromaDB.
set -Eeuo pipefail

log() { echo "[odysseus-integrate] $*"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
export ODYSSEUS_RUNTIME_VAULT_PATH="${ODYSSEUS_RUNTIME_VAULT_PATH:-yieldswarm/data/odysseus/runtime}"
export AKASH_OLLAMA_BASE_URL="${AKASH_OLLAMA_BASE_URL:-http://ollama:11434}"
export YIELDSWARM_ROUTER_API_KEY="${YIELDSWARM_ROUTER_API_KEY:-sk-yieldswarm-local}"

log "Starting Odysseus stack (ChromaDB + LiteLLM + SearXNG + ntfy)"
docker compose up -d odysseus llm-router chromadb searxng ntfy

if command -v nvidia-smi >/dev/null 2>&1; then
  log "GPU detected — starting Ollama + model router"
  docker compose --profile gpu --profile routing up -d ollama model-router-api
else
  log "No GPU — skipping Ollama profile"
fi

log "Starting Kairo API"
docker compose up -d kairo-api

log "Syncing model router → LiteLLM"
sleep 5
curl -fsS -X POST "http://localhost:${MODEL_ROUTER_PORT:-8090}/sync-litellm" \
  -H "Content-Type: application/json" \
  -d "{\"ollama_base_url\":\"${AKASH_OLLAMA_BASE_URL}\"}" || log "WARN: model router sync failed (may not be running)"

log "Health checks:"
for url in \
  "http://localhost:${ODYSSEUS_PORT:-7000}/healthz" \
  "http://localhost:${LITELLM_PORT:-4000}/health" \
  "http://localhost:${CHROMADB_PORT:-8000}/api/v1/heartbeat" \
  "http://localhost:${KAIRO_API_PORT:-8092}/health"; do
  if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
    log "  OK  $url"
  else
    log "  --  $url (not ready yet)"
  fi
done

log "Odysseus integration complete. ChromaDB memory: agents/odysseus_memory.py"
log "External providers: Fireworks + OpenRouter via config/litellm/config.yaml"

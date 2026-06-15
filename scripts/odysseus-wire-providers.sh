#!/usr/bin/env bash
# Wire Odysseus LiteLLM router to external providers + Akash Ollama workers.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/vault-env.sh
. "${ROOT_DIR}/scripts/lib/vault-env.sh"

VAULT_PATH="${ODYSSEUS_RUNTIME_VAULT_PATH:-kv/data/yieldswarm/odysseus/runtime}"

log() { echo "[odysseus-wire] $*"; }

load_secrets() {
  if [ -n "${VAULT_ADDR:-}" ]; then
    log "Loading Odysseus runtime secrets from Vault: ${VAULT_PATH}"
    vault_export_env "${VAULT_PATH}"
  else
    log "VAULT_ADDR not set — using existing environment"
  fi
}

verify_providers() {
  local ok=0

  if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    log "✓ OpenRouter configured (model: ${OPENROUTER_MODEL:-default})"
    ok=$((ok + 1))
  else
    log "✗ OPENROUTER_API_KEY missing"
  fi

  if [ -n "${FIREWORKS_API_KEY:-}" ]; then
    log "✓ Fireworks configured (model: ${FIREWORKS_MODEL:-default})"
    ok=$((ok + 1))
  else
    log "✗ FIREWORKS_API_KEY missing"
  fi

  if [ -n "${AKASH_OLLAMA_BASE_URL:-}" ]; then
    log "✓ Akash Ollama workers: ${AKASH_OLLAMA_BASE_URL}"
    if curl -sf --max-time 5 "${AKASH_OLLAMA_BASE_URL}/api/tags" >/dev/null 2>&1; then
      log "  → Ollama endpoint reachable"
    else
      log "  → Ollama endpoint not reachable (may be behind private network)"
    fi
    ok=$((ok + 1))
  else
    log "✗ AKASH_OLLAMA_BASE_URL missing — set after Akash lease deploys"
  fi

  if [ -n "${CHROMADB_URL:-}" ] || [ -n "${ODYSSEUS_CHROMADB_HOST:-}" ]; then
    log "✓ ChromaDB configured"
    ok=$((ok + 1))
  else
    log "✗ ChromaDB not configured — Odysseus will use JSONL fallback"
  fi

  log "Provider check: ${ok}/4 configured"
}

render_litellm_config() {
  local out="${ROOT_DIR}/build/litellm/config.rendered.yaml"
  mkdir -p "$(dirname "$out")"
  cp "${ROOT_DIR}/config/litellm/config.yaml" "$out"
  log "LiteLLM config at ${out}"
}

register_swarm_agents() {
  log "Registering 10,080 agents + 169 deities with Odysseus memory..."
  if command -v python3 >/dev/null 2>&1; then
    python3 "${ROOT_DIR}/agents/bootstrap-deity-identities.py" 2>/dev/null || true
    python3 -c "
from agents.odysseus_memory import OdysseusMemoryAdapter
adapter = OdysseusMemoryAdapter()
print(f'ChromaDB collections: {list(adapter.collections.keys()) if hasattr(adapter, \"collections\") else \"fallback\"}')
" 2>/dev/null || log "Memory adapter bootstrap skipped (ChromaDB may be offline)"
  fi
}

main() {
  load_secrets
  verify_providers
  render_litellm_config
  register_swarm_agents
  log "Done. Start Odysseus with: docker compose up -d odysseus"
  log "Or deploy to Akash: scripts/deploy-production-odysseus.sh akash"
}

main "$@"

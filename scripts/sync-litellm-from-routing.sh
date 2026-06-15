#!/usr/bin/env bash
# Export AKASH_OLLAMA_BASE_URL from Odysseus routing state for LiteLLM reload.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTING_FILE="${ODYSSEUS_ROUTING_STATE_PATH:-$REPO_ROOT/.run/odysseus-routing.json}"

if [[ ! -f "$ROUTING_FILE" ]]; then
  echo "Routing state not found: $ROUTING_FILE" >&2
  echo "Run: curl -X POST http://localhost:8080/api/models/sync" >&2
  exit 1
fi

OLLAMA_URL="$(python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
print(data.get('akash_ollama_base_url') or '')
" "$ROUTING_FILE")"

if [[ -z "$OLLAMA_URL" ]]; then
  echo "No akash_ollama_base_url in routing state — using live sync" >&2
  cd "$REPO_ROOT"
  OLLAMA_URL="$(python3 -c "from services.akash_worker_sync import primary_ollama_base_url; print(primary_ollama_base_url() or '')")"
fi

if [[ -z "$OLLAMA_URL" ]]; then
  echo "No Akash Ollama endpoint available" >&2
  exit 1
fi

export AKASH_OLLAMA_BASE_URL="$OLLAMA_URL"
echo "export AKASH_OLLAMA_BASE_URL=$OLLAMA_URL"
echo "# LiteLLM: restart llm-router after sourcing this, or POST /reload to LiteLLM admin"

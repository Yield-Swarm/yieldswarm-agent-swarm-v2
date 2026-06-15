#!/usr/bin/env bash
# Start the Odysseus central brain locally (memory + model router + tools).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PYTHONPATH="${ROOT}:${ROOT}/agents"
export PORT="${ODYSSEUS_BRAIN_PORT:-8080}"
export HOST="${ODYSSEUS_BRAIN_HOST:-0.0.0.0}"
export ODYSSEUS_API_KEY="${ODYSSEUS_API_KEY:-dev-odysseus-key}"
export YIELDSWARM_ROUTER_API_KEY="${YIELDSWARM_ROUTER_API_KEY:-dev-router-key}"
export ODYSSEUS_CHROMA_MODE="${ODYSSEUS_CHROMA_MODE:-jsonl}"
export ODYSSEUS_SYNC_PORT="${ODYSSEUS_SYNC_PORT:-8097}"

if [ "${1:-}" = "sync-only" ]; then
  exec python3 agents/odysseus-sync-service.py
fi

echo "Starting Odysseus brain on http://${HOST}:${PORT}"
exec python3 -m services.odysseus.main

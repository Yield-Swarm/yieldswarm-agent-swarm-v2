#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-up}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

case "$COMMAND" in
  up)
    docker compose config >/dev/null
    docker compose up -d --build
    ;;
  up-local-ollama)
    COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}" docker compose --profile local-ollama up -d --build
    ;;
  gpu-up)
    COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml:docker/gpu.nvidia.yml}" docker compose config >/dev/null
    COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml:docker/gpu.nvidia.yml}" docker compose --profile local-ollama up -d --build
    ;;
  down)
    docker compose down
    ;;
  status)
    docker compose ps
    ;;
  config)
    docker compose config
    ;;
  render-akash)
    python3 scripts/render-akash-sdl.py "${@:2}"
    ;;
  *)
    cat >&2 <<'USAGE'
Usage: scripts/deploy-odysseus-stack.sh <command>

Commands:
  up             Validate and start Odysseus, LiteLLM router, ChromaDB, SearXNG, ntfy
  up-local-ollama
                 Start the stack plus the optional local Ollama service
  gpu-up         Start with docker/gpu.nvidia.yml and local Ollama profile
  down           Stop the local compose stack
  status         Show compose service status
  config         Render docker compose config
  render-akash   Render deploy/akash-odysseus.sdl.yml with env vars
USAGE
    exit 2
    ;;
esac

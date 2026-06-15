#!/usr/bin/env bash
set -euo pipefail

SDL_PATH="infra/akash/openclaw-worker-r3090.sdl.yml"

if [[ ! -f "${SDL_PATH}" ]]; then
  echo "Missing SDL at ${SDL_PATH}"
  exit 1
fi

echo "[akash] validating SDL: ${SDL_PATH}"
echo "[akash] dry-run only in scaffold mode"
echo "[akash] next: provider-services tx create deployment --sdl ${SDL_PATH}"

#!/usr/bin/env bash
# Boot Runic Realms MMORPG (server + optional client dev)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT/apps/runic-realms/server"
npm install --silent 2>/dev/null || true
if [[ "${1:-}" == "dev" ]]; then
  npm start &
  cd "$ROOT/apps/runic-realms/client"
  npm install --silent 2>/dev/null || true
  exec npm run dev
else
  exec npm start
fi

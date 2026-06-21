#!/usr/bin/env bash
# scripts/run-tv-dashboard.sh — boot unified command dashboard for TV + Pixel
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PORT="${PORT:-8080}"
log() { printf '[tv-dashboard] %s\n' "$*" >&2; }

if [[ -f .env ]]; then set -a; source .env; set +a; fi
if [[ -f deploy/config.env ]]; then set -a; source deploy/config.env; set +a; fi

log "Starting backend on :$PORT"
log "Open on TV browser: http://$(hostname -I 2>/dev/null | awk '{print $1}'):${PORT}/command"
log "Pixel / phone:      http://localhost:${PORT}/command"

if [[ -x scripts/run-solenoids-production.sh ]]; then
  exec ./scripts/run-solenoids-production.sh
else
  cd backend && npm install --silent 2>/dev/null || true
  exec node src/server.js
fi

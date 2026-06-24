#!/usr/bin/env bash
# Cursor Cloud Agent environment bootstrap — matches .github/workflows/ci.yml
# Do NOT add npm start or long-running servers here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

log() { printf '[cursor-install] %s\n' "$*"; }

log "Installing root (Next.js payments app)..."
npm ci

log "Installing backend..."
(cd backend && npm ci)

log "Installing frontend..."
(cd frontend && npm ci)

if [[ -f requirements.txt ]]; then
  log "Installing Python requirements..."
  pip install -q -r requirements.txt eth-account 2>/dev/null || pip install -q -r requirements.txt
fi

log "Smoke: mining module..."
PYTHONPATH="${ROOT}" python3 -m mining hashpower --json >/dev/null

log "Done. Start dev servers manually:"
log "  npm run dev          # :3000"
log "  npm run dev:backend  # :8080"
log "  npm run dev:frontend # Vite"

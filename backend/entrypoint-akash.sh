#!/usr/bin/env bash
# Akash entrypoint: load Vault secrets, then start integration backend.
set -euo pipefail

log() { printf '[backend-entrypoint] %s\n' "$*" >&2; }

export PORT="${PORT:-8080}"
export HOST="${HOST:-0.0.0.0}"

if [[ -n "${VAULT_ADDR:-}" ]]; then
  log "Loading secrets from Vault"
  if python3 /app/scripts/vault-export-env.py backend > /run/secrets/app.env 2>/dev/null; then
    # shellcheck disable=SC1091
    set -a && source /run/secrets/app.env && set +a
    log "Vault secrets loaded (vault-export-env)"
  elif [[ -s /run/secrets/env ]]; then
    set -a && source /run/secrets/env && set +a
    log "Vault secrets loaded (vault-agent sidecar)"
  else
    log "WARN: VAULT_ADDR set but no secrets rendered — using SDL env only"
  fi
fi

log "Starting integration backend on ${HOST}:${PORT}"
cd /app/backend
exec node src/server.js

#!/usr/bin/env sh
# Backend container entrypoint — unwrap Vault bootstrap + load runtime secrets.
set -eu

mkdir -p /run/secrets

if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_ROLE_ID:-}" ]; then
  if python3 /app/scripts/vault-export-env.py akash > /run/secrets/app.env 2>/dev/null; then
    set -a
    # shellcheck disable=SC1091
    . /run/secrets/app.env
    set +a
  elif [ -f /run/secrets/agent.env ]; then
    set -a
    # shellcheck disable=SC1091
    . /run/secrets/agent.env
    set +a
  fi
  unset VAULT_WRAPPED_SECRET_ID VAULT_SECRET_ID_WRAP_TOKEN VAULT_SECRET_ID 2>/dev/null || true
fi

exec "$@"

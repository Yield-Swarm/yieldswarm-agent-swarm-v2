#!/usr/bin/env bash
# Container healthcheck. Verifies:
#   * Vault is reachable from this container
#   * our token is still valid (lookup-self works)
# Exits non-zero on failure so the orchestrator will restart us.
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR not set}"

if ! vault status >/dev/null 2>&1; then
  echo "vault status failed against ${VAULT_ADDR}" >&2
  exit 1
fi

if [[ -n "${VAULT_TOKEN:-}" ]]; then
  if ! vault token lookup -self >/dev/null 2>&1; then
    echo "vault token lookup-self failed" >&2
    exit 2
  fi
fi

exit 0

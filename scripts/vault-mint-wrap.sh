#!/usr/bin/env bash
# Mint a single-use wrapped SecretID for Akash runtime AppRole.
# Requires VAULT_ADDR and VAULT_TOKEN (or ci-bootstrap AppRole creds).
set -Eeuo pipefail

log() { echo "[vault-mint-wrap] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

: "${VAULT_ADDR:?VAULT_ADDR is required}"

APPROLE="${VAULT_AKASH_APPROLE:-akash-runtime}"
WRAP_TTL="${VAULT_WRAP_TTL:-600s}"

if [ -z "${VAULT_TOKEN:-}" ]; then
  if [ -n "${VAULT_CI_ROLE_ID:-}" ] && [ -n "${VAULT_CI_SECRET_ID:-}" ]; then
    log "Logging in via ci-bootstrap AppRole"
    VAULT_TOKEN=$(vault write -format=json auth/approle/login \
      role_id="${VAULT_CI_ROLE_ID}" \
      secret_id="${VAULT_CI_SECRET_ID}" \
      | jq -er '.auth.client_token')
    export VAULT_TOKEN
  else
    die "Set VAULT_TOKEN or VAULT_CI_ROLE_ID + VAULT_CI_SECRET_ID"
  fi
fi

ROLE_ID=$(vault read -field=role_id "auth/approle/role/${APPROLE}/role-id") \
  || die "Failed to read role_id for ${APPROLE}"

WRAP=$(vault write -wrap-ttl="${WRAP_TTL}" -force -format=json \
  "auth/approle/role/${APPROLE}/secret-id" \
  | jq -er '.wrap_info.token') \
  || die "Failed to mint wrapped SecretID"

# Output as shell-exportable vars (safe for sourcing in deploy scripts)
printf 'export VAULT_ROLE_ID=%q\n' "${ROLE_ID}"
printf 'export VAULT_WRAPPED_SECRET_ID=%q\n' "${WRAP}"

#!/usr/bin/env bash
# vault/setup/02-enable-engines.sh
#
# Enable the secret engines + audit devices YieldSwarm depends on.
# Idempotent: re-running is a no-op if everything is already mounted.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib.sh"
require_token

# ---- KVv2 mount for application secrets --------------------------------
ensure_engine kv yieldswarm "-version=2 -description=YieldSwarm_application_secrets"

# ---- Transit (envelope encryption) -------------------------------------
ensure_engine transit transit "-description=YieldSwarm_transit_envelope_encryption"

# Two named keys: one for Terraform-state, one for in-app data.
for k in terraform-state agent-runtime; do
  if ! vault read -format=json "transit/keys/${k}" >/dev/null 2>&1; then
    log "Creating transit key ${k}"
    vault write -f "transit/keys/${k}" type=aes256-gcm96 derived=false convergent_encryption=false >/dev/null
  else
    log "Transit key ${k} already exists - skipping"
  fi
done

# ---- (Optional) PKI for internal mTLS ----------------------------------
if [ "${ENABLE_PKI:-true}" = "true" ]; then
  ensure_engine pki pki "-max-lease-ttl=87600h"
fi

# ---- (Optional) Database engine for dynamic DB creds -------------------
if [ "${ENABLE_DB:-false}" = "true" ]; then
  ensure_engine database database
fi

# ---- Audit device (file) -----------------------------------------------
AUDIT_PATH="${AUDIT_FILE_PATH:-/var/log/vault/audit.log}"
if ! vault audit list -format=json | jq -er '."file/"' >/dev/null 2>&1; then
  log "Enabling file audit device at ${AUDIT_PATH}"
  vault audit enable file file_path="${AUDIT_PATH}"
else
  log "File audit device already enabled - skipping"
fi

log "Engines + audit complete."

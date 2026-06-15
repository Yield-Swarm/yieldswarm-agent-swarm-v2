#!/usr/bin/env bash
# Enable KV v2 secrets engine at yieldswarm/ mount.
# Idempotent — safe to re-run.
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

MOUNT_PATH="yieldswarm"

if vault secrets list -format=json | jq -e --arg p "${MOUNT_PATH}/" '.[$p]' >/dev/null 2>&1; then
  echo "Secrets engine ${MOUNT_PATH}/ already enabled"
else
  vault secrets enable -path="${MOUNT_PATH}" -version=2 kv
  echo "Enabled KV v2 at ${MOUNT_PATH}/"
fi

# Tune for production: versioning, max versions, delete protection.
vault write "${MOUNT_PATH}/config" \
  max_versions=10 \
  delete_version_after="720h" \
  cas_required=true

echo "Secrets engine ${MOUNT_PATH}/ configured"

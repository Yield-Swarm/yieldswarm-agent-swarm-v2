#!/usr/bin/env bash
# vault_runtime_export.sh — AppRole unwrap + KV export to ephemeral runtime dir
#
# NEVER hardcode secrets in this script. Load from Vault or operator env files.
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.io:8200
#   export VAULT_ROLE_ID=... VAULT_SECRET_ID=...   # or VAULT_TOKEN for bootstrap
#   ./scripts/edge/vault_runtime_export.sh
#
# Output: /tmp/run_secrets/app.env (mode 600) — sourced by edge workers only
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${YIELDSWARM_LOG_DIR:-$HOME/yieldswarm-logs}"
RUN_SECRETS="${RUN_SECRETS_DIR:-/tmp/run_secrets}"
APP_ENV="${RUN_SECRETS}/app.env"

log() { printf '[vault-export] %s\n' "$*" >&2; }

mkdir -p "${LOG_DIR}" "${RUN_SECRETS}"

# shellcheck source=scripts/lib/vault-env.sh
source "${REPO_ROOT}/scripts/lib/vault-env.sh" 2>/dev/null || {
  log "ERROR: scripts/lib/vault-env.sh missing"
  exit 1
}

: "${VAULT_ADDR:?Set VAULT_ADDR}"

log "Task 2 — exporting runtime bundle from Vault (yieldswarm/)"

# AppRole login when token not set
if [[ -z "${VAULT_TOKEN:-}" ]] && [[ -n "${VAULT_ROLE_ID:-}" ]] && [[ -n "${VAULT_SECRET_ID:-}" ]]; then
  VAULT_TOKEN="$(vault write -field=token auth/approle/login \
    role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}")"
  export VAULT_TOKEN
fi

: "${VAULT_TOKEN:?Set VAULT_TOKEN or VAULT_ROLE_ID + VAULT_SECRET_ID}"

KV_MOUNT="${KV_MOUNT:-yieldswarm}"

fetch_kv() {
  local path="$1"
  vault kv get -format=json "${KV_MOUNT}/${path}" 2>/dev/null | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('data',{}).get('data',{})))"
}

# Paths — extend as needed; values never logged
W3B=$(fetch_kv "integrations/iotex" 2>/dev/null || echo '{}')
S3=$(fetch_kv "providers/aws" 2>/dev/null || echo '{}')

{
  echo "# Ephemeral runtime — generated $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "export VAULT_PATH_MOUNT=${KV_MOUNT}"
  echo "export IOTEX_W3BSTREAM_ENDPOINT=\"${IOTEX_W3BSTREAM_ENDPOINT:-}\""
  echo "export IOTEX_DEVICE_ID=\"${IOTEX_DEVICE_ID:-io_nexus_pebble_01}\""
  # AWS from Vault JSON (keys must exist in providers/aws)
  python3 - "${W3B}" "${S3}" <<'PY'
import json, os, sys
iotex = json.loads(sys.argv[1] or "{}")
aws = json.loads(sys.argv[2] or "{}")
w3b = iotex.get("w3bstream_token") or os.environ.get("W3BSTREAM_PROJECT_TOKEN", "")
if w3b:
    print(f'export W3BSTREAM_PROJECT_TOKEN="{w3b}"')
ak = aws.get("access_key_id") or aws.get("client_id", "")
sk = aws.get("secret_access_key") or aws.get("client_secret", "")
if ak:
    print(f'export AWS_ACCESS_KEY_ID="{ak}"')
if sk:
    print(f'export AWS_SECRET_ACCESS_KEY="{sk}"')
PY
} >"${APP_ENV}"

chmod 600 "${APP_ENV}"
log "wrote ${APP_ENV} (memory-isolated path — do not commit)"

echo "vault_runtime_export OK" >>"${LOG_DIR}/vault_auth.log"

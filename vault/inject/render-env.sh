#!/usr/bin/env bash
# vault/inject/render-env.sh — render agent.env for Azure, Akash, or Vast.ai
#
# Usage:
#   PROVIDER=azure|akash|vastai ./vault/inject/render-env.sh
#   AGENT_ENV_FILE=/run/secrets/agent.env ./vault/inject/render-env.sh

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

PROVIDER="${PROVIDER:-akash}"
TEMPLATE="${SCRIPT_DIR}/templates/${PROVIDER}.env.ctmpl"
AGENT_CONFIG="${SCRIPT_DIR}/agents/${PROVIDER}-agent.hcl"

if [[ ! -f "${TEMPLATE}" ]]; then
  log "unknown provider ${PROVIDER}"
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

if command -v consul-template >/dev/null 2>&1; then
  vault_login
  export VAULT_KV_MOUNT="${KV_MOUNT}"
  consul-template \
    -vault-addr="${VAULT_ADDR}" \
    -vault-token="${VAULT_TOKEN}" \
    -template "${TEMPLATE}:${OUTPUT_FILE}" \
    -once
elif command -v vault >/dev/null 2>&1; then
  vault_login
  {
    echo "# generated $(date -u +%Y-%m-%dT%H:%M:%SZ) provider=${PROVIDER}"
    case "${PROVIDER}" in
      nexus)
        kv_export runtime/nexus || true
        kv_export runtime/core || true
        kv_export providers/azure || true
        ;;
      helix)
        kv_export runtime/helix || true
        kv_export runtime/wallets || true
        kv_export runtime/zk || true
        kv_export rpc/solana || true
        ;;
      shadow)
        kv_export runtime/shadow || true
        kv_export runtime/zk || true
        kv_export runtime/backend || true
        ;;
      azure)
        kv_export providers/azure || true
        kv_export runtime/nexus || true
        ;;
      akash)
        kv_export runtime/akash || true
        kv_export runtime/backend || true
        kv_export rpc/solana || true
        ;;
      vastai)
        kv_export providers/vastai || true
        kv_export runtime/helix || true
        ;;
    esac
  } > "${OUTPUT_FILE}"
else
  log "no vault/consul-template — writing stub env"
  echo "# vault inject stub provider=${PROVIDER}" > "${OUTPUT_FILE}"
fi

chmod 600 "${OUTPUT_FILE}" 2>/dev/null || true
log "done → ${OUTPUT_FILE}"

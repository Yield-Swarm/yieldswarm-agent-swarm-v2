#!/usr/bin/env bash
# Trident Protocol — Ethereum Classic (ETC) / etchash fallback channel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLET="${MINING_ROOT_BASE_ETC:-${ETC_WALLET_ADDRESS:-}}"
WORKER="${ETC_WORKER_NAME:-16xH100-ETC-Fleet1}"
POOL="${ETC_POOL_URL:-etc.2miners.com:1010}"
SRB="${SRBMINER_PATH:-${SCRIPT_DIR}/SRBMiner-MULTI}"
DRY_RUN="${MINING_DRY_RUN:-0}"

log() { printf '[%s] [mine_etc] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

if [[ -z "${WALLET}" ]]; then
  log "ERROR: set MINING_ROOT_BASE_ETC"
  exit 1
fi

CMD=(
  "${SRB}"
  --algorithm etchash
  --pool "${POOL}"
  --wallet "${WALLET}.${WORKER}"
  --password x
  --disable-cpu
  --gpu 0-15
)

log "ETC etchash pool=${POOL}"

if [[ "${DRY_RUN}" == "1" || "${DRY_RUN}" == "true" ]]; then
  printf '  '; printf '%q ' "${CMD[@]}"; echo
  exit 0
fi

chmod +x "${SRB}" 2>/dev/null || true
exec "${CMD[@]}"

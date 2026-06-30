#!/usr/bin/env bash
# Trident Protocol — Ergo (ERG) / autolykos2 fallback channel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLET="${ERG_WALLET_ADDRESS:-${MINING_WALLET_ERG:-}}"
WORKER="${ERG_WORKER_NAME:-16xH100-ERG-Fleet1}"
POOL="${ERG_POOL_URL:-ergo.2miners.com:1111}"
SRB="${SRBMINER_PATH:-${SCRIPT_DIR}/SRBMiner-MULTI}"
DRY_RUN="${MINING_DRY_RUN:-0}"

log() { printf '[%s] [mine_erg] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

if [[ -z "${WALLET}" ]]; then
  log "ERROR: set ERG_WALLET_ADDRESS"
  exit 1
fi

CMD=(
  "${SRB}"
  --algorithm autolykos2
  --pool "${POOL}"
  --wallet "${WALLET}.${WORKER}"
  --password x
  --disable-cpu
  --gpu 0-15
)

log "ERG autolykos2 pool=${POOL}"

if [[ "${DRY_RUN}" == "1" || "${DRY_RUN}" == "true" ]]; then
  printf '  '; printf '%q ' "${CMD[@]}"; echo
  exit 0
fi

chmod +x "${SRB}" 2>/dev/null || true
exec "${CMD[@]}"

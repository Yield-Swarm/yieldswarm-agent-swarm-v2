#!/usr/bin/env bash
# Trident Protocol — Pearl (PRL) / PearlHash deployment for 16× H100/H200 fleet.
# Primary $36k credit PoUW engine (matrix multiplication / pearlhash).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Wallet must be prl1… bech32m (NOT Solana). Pool must be Pearl (NOT etc.2miners.com:1010).
WALLET="${MINING_ROOT_PRL:-${MINING_WALLET_PRL:-}}"
WORKER="${PRL_WORKER_NAME:-16xH100-YieldSwarm-Fleet1}"
POOL="${MINING_POOL_URL_PRL:-prl.2miners.com:1818}"
SRB="${SRBMINER_PATH:-${SCRIPT_DIR}/SRBMiner-MULTI}"
GPU_THREADS="${PRL_GPU_THREADS:-2}"
CPU_COOLDOWN="${PRL_CPU_COOLDOWN:-50}"
DRY_RUN="${MINING_DRY_RUN:-0}"

log() { printf '[%s] [mine_prl] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

if [[ -z "${WALLET}" ]]; then
  log "ERROR: set MINING_ROOT_PRL (prl1p… address)"
  exit 1
fi

if [[ "${WALLET}" != prl1* ]]; then
  log "ERROR: wallet must start with prl1 — got ${WALLET:0:12}…"
  exit 1
fi

if [[ "${POOL}" == *etc.2miners* || "${POOL}" == *:1010* ]]; then
  log "ERROR: ${POOL} is ETC — use prl.2miners.com:1818 for pearlhash"
  exit 1
fi

WALLET_WORKER="${WALLET}.${WORKER}"
mkdir -p "${ROOT}/.run/trident"

CMD=(
  "${SRB}"
  --algorithm pearlhash
  --pool "${POOL}"
  --wallet "${WALLET_WORKER}"
  --password x
  --gpu-threads "${GPU_THREADS}"
  --disable-cpu
  --pearl-cpu-cooldown "${CPU_COOLDOWN}"
)

log "Launching PearlHash on 16× H100/H200 fleet pool=${POOL} worker=${WORKER}"

if [[ "${DRY_RUN}" == "1" || "${DRY_RUN}" == "true" ]]; then
  printf '  '; printf '%q ' "${CMD[@]}"; echo
  exit 0
fi

if [[ ! -x "${SRB}" ]] && ! command -v "${SRB}" >/dev/null 2>&1; then
  log "ERROR: SRBMiner-MULTI not found at ${SRB}"
  exit 1
fi

chmod +x "${SRB}" 2>/dev/null || true
exec "${CMD[@]}"

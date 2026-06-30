#!/usr/bin/env bash
# SAA V2 Sub-Swarm: Pearl (PRL) deployment via SRBMiner-MULTI / pearlhash.
#
# YieldSwarm-native PoWUoI coin. Defaults to 2Miners Pearl pool (NOT etc.2miners.com).
#
# Usage:
#   export MINING_ROOT_PRL=prl1p...   # or Solana treasury root if pool accepts it
#   export PRL_WORKER_NAME=16xH100-YieldSwarm-Fleet1
#   ./scripts/mining/deploy-pearl-srbminer.sh
#
# Optional:
#   MINING_POOL_URL_PRL=us-prl.2miners.com:1818
#   PRL_GPU_THREADS=2
#   PRL_CPU_COOLDOWN=50
#   SRBMINER_PATH=/path/to/SRBMiner-MULTI
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/mining/lib/srbminer-common.sh
source "${REPO_ROOT}/scripts/mining/lib/srbminer-common.sh"

WALLET_ADDRESS="${MINING_ROOT_PRL:-${MINING_WALLET_PRL:-}}"
WORKER_NAME="$(srbminer_sanitize_worker "${PRL_WORKER_NAME:-16xH100-YieldSwarm-Fleet1}")"
POOL_URL="${MINING_POOL_URL_PRL:-prl.2miners.com:1818}"
GPU_THREADS="${PRL_GPU_THREADS:-2}"
PEARL_CPU_COOLDOWN="${PRL_CPU_COOLDOWN:-50}"
DRY_RUN="${MINING_DRY_RUN:-1}"

if [[ -z "${WALLET_ADDRESS}" ]]; then
  echo "[pearl] ERROR: set MINING_ROOT_PRL or MINING_WALLET_PRL" >&2
  exit 1
fi

if [[ "${DISABLE_RUNPOD_MINING:-false}" == "true" ]]; then
  echo "[pearl] WARN: DISABLE_RUNPOD_MINING=true — use Cherry/Akash/Azure fleet instead of RunPod" >&2
fi

WALLET_WORKER="$(srbminer_wallet_worker "${WALLET_ADDRESS}" "${WORKER_NAME}")"

echo "🚀 Launching SAA V2 Matrix Compute Node on PearlHash (PRL)..."
echo "   pool=${POOL_URL} worker=${WORKER_NAME} algorithm=pearlhash"

CMD=(
  SRBMiner-MULTI
  --algorithm pearlhash
  --pool "${POOL_URL}"
  --wallet "${WALLET_WORKER}"
  --password x
  --gpu-threads "${GPU_THREADS}"
  --disable-cpu
  --pearl-cpu-cooldown "${PEARL_CPU_COOLDOWN}"
)

if [[ "${DRY_RUN}" == "1" || "${DRY_RUN}" == "true" ]]; then
  echo "[pearl] DRY_RUN — command:"
  printf '  %q' "${CMD[@]}"
  echo
  exit 0
fi

SRB="$(srbminer_resolve_binary)"
CMD[0]="${SRB}"
chmod +x "${SRB}" 2>/dev/null || true
exec "${CMD[@]}"

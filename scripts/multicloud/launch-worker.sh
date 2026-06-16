#!/usr/bin/env bash
# Route workload launch to a cloud provider.
# Usage: PROVIDER=akash WORKLOAD=bittensor DRY_RUN=1 ./scripts/multicloud/launch-worker.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDER="${PROVIDER:?set PROVIDER}"
WORKLOAD="${WORKLOAD:-bittensor}"
GPU="${GPU:-RTX_3090}"
DRY_RUN="${DRY_RUN:-1}"
PROVIDER_SCRIPT="${SCRIPT_DIR}/providers/${PROVIDER}.sh"
if [[ -x "${PROVIDER_SCRIPT}" ]]; then
  export WORKLOAD GPU DRY_RUN
  exec "${PROVIDER_SCRIPT}" launch
fi
echo "[multicloud] simulated launch provider=${PROVIDER} workload=${WORKLOAD} gpu=${GPU} dry_run=${DRY_RUN}"

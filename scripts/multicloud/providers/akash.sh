#!/usr/bin/env bash
# Akash provider launch
set -euo pipefail
WORKLOAD="${WORKLOAD:-bittensor}"
if [[ "${DRY_RUN:-1}" == "1" ]]; then
  echo "[dry-run] Akash launch workload=${WORKLOAD}"
  exit 0
fi
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SDL="deploy/akash-bittensor-miner.sdl.yml"
[[ "${WORKLOAD}" == "inference" ]] && SDL="deploy/deploy-swarm-monolith.yaml"
exec bash "${REPO_ROOT}/scripts/deploy-to-akash.sh" deploy "${SDL}" 2>/dev/null || echo "[akash] deploy-to-akash.sh not available"

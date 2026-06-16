#!/usr/bin/env bash
set -euo pipefail
if [[ "${DRY_RUN:-1}" == "1" ]]; then echo "[dry-run] RunPod launch WORKLOAD=${WORKLOAD:-training}"; exit 0; fi
echo "RunPod launch requires RUNPOD_API_KEY"
exit 1

#!/usr/bin/env bash
set -euo pipefail
if [[ "${DRY_RUN:-1}" == "1" ]]; then echo "[dry-run] Vast launch WORKLOAD=${WORKLOAD:-training} GPU=${GPU:-RTX_4090}"; exit 0; fi
echo "Vast launch requires VAST_API_KEY — see docs/MULTI_CLOUD_30DAY_PLAN.md"
exit 1

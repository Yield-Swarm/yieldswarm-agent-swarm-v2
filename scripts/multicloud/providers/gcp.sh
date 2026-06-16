#!/usr/bin/env bash
set -euo pipefail
if [[ "${DRY_RUN:-1}" == "1" ]]; then echo "[dry-run] GCP launch WORKLOAD=${WORKLOAD:-grass}"; exit 0; fi
echo "GCP launch via infra/terraform"
exit 0

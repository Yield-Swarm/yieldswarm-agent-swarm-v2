#!/usr/bin/env bash
set -euo pipefail
if [[ "${DRY_RUN:-1}" == "1" ]]; then echo "[dry-run] Azure launch WORKLOAD=${WORKLOAD:-grass}"; exit 0; fi
echo "Azure launch via infra/terraform — see infra/README.md"
exit 0

#!/usr/bin/env bash
# GCP provider — delegates to infra/terraform gcp-mig module.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"

case "${1:-launch}" in
  launch)
    WORKLOAD="${WORKLOAD:-grass}"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[dry-run] GCP launch workload=${WORKLOAD} via infra/terraform"
      exit 0
    fi
    echo "GCP launch: cd infra/terraform && terraform apply -var='enabled_fallbacks=[\"gcp\"]'"
    echo "Workload=${WORKLOAD} — use gcp-mig module (see infra/README.md)"
  ;;
  teardown)
    echo "GCP teardown: cd infra/terraform && terraform destroy -target=module.gcp_mig"
  ;;
  *) echo "usage: $0 [launch|teardown]"; exit 1 ;;
esac

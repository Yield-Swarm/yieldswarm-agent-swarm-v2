#!/usr/bin/env bash
# Azure provider — delegates to infra/terraform azure-vmss module.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"

case "${1:-launch}" in
  launch)
    WORKLOAD="${WORKLOAD:-grass}"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[dry-run] Azure launch workload=${WORKLOAD} via infra/terraform"
      exit 0
    fi
    if [[ ! -d "${TF_DIR}" ]]; then
      echo "infra/terraform not found"
      exit 1
    fi
    echo "Azure launch: cd infra/terraform && terraform apply -var='enabled_fallbacks=[\"azure\"]'"
    echo "Workload=${WORKLOAD} — use azure-vmss module (see infra/README.md)"
  ;;
  teardown)
    echo "Azure teardown: cd infra/terraform && terraform destroy -target=module.azure_vmss"
  ;;
  *) echo "usage: $0 [launch|teardown]"; exit 1 ;;
esac

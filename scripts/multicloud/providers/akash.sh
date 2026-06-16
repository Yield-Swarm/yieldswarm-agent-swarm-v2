#!/usr/bin/env bash
# Akash provider — delegates to production deploy scripts.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

case "${1:-launch}" in
  launch)
    WORKLOAD="${WORKLOAD:-bittensor}"
    case "${WORKLOAD}" in
      bittensor)
        SDL="${AKASH_SDL:-deploy/akash-bittensor-miner.sdl.yml}"
        ;;
      inference|sovereign)
        SDL="${AKASH_SDL:-deploy/deploy-swarm-monolith.yaml}"
        ;;
      *)
        SDL="${AKASH_SDL:-deploy/deploy-swarm-monolith.yaml}"
        ;;
    esac
    echo "Akash launch: workload=${WORKLOAD} sdl=${SDL}"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[dry-run] would run: scripts/deploy-to-akash.sh deploy ${SDL}"
      exit 0
    fi
    exec bash "${REPO_ROOT}/scripts/deploy-to-akash.sh" deploy "${SDL}"
    ;;
  teardown)
    echo "Akash teardown: close deployment via provider-services"
    if [[ -f "${REPO_ROOT}/.run/akash-deploy.json" ]]; then
      DEPLOY_ID="$(jq -r '.deployment_id // .deployment // empty' "${REPO_ROOT}/.run/akash-deploy.json")"
      echo "deployment_id=${DEPLOY_ID} — run: provider-services tx deployment close --dseq ${DEPLOY_ID}"
    else
      echo "no .run/akash-deploy.json found"
    fi
    ;;
  *) echo "usage: $0 [launch|teardown]"; exit 1 ;;
esac

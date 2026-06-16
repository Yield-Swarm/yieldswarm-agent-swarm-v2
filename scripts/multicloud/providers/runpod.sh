#!/usr/bin/env bash
# RunPod GPU burst provider (scaffold — requires RUNPOD_API_KEY).
set -euo pipefail

RUNPOD_API_KEY="${RUNPOD_API_KEY:-}"
RUNPOD_ENDPOINT="${RUNPOD_ENDPOINT:-https://api.runpod.io/graphql}"
GPU="${GPU:-RTX_4090}"
WORKLOAD="${WORKLOAD:-inference}"
IMAGE="${RUNPOD_IMAGE:-ghcr.io/yield-swarm/yieldswarm-agent:latest}"

case "${1:-launch}" in
  launch)
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[dry-run] RunPod launch GPU=${GPU} workload=${WORKLOAD}"
      exit 0
    fi
    if [[ -z "${RUNPOD_API_KEY}" ]]; then
      echo "RUNPOD_API_KEY not set — add to Vault: kv/yieldswarm/cloud/runpod"
      echo "[scaffold] would deploy pod GPU=${GPU} image=${IMAGE}"
      exit 1
    fi
    # GraphQL pod deploy (matches terraform/runpod.tf pattern)
    QUERY='mutation { podFindAndDeployOnDemand(input: {
      name: "yieldswarm-'"${WORKLOAD}"'-'"$(date +%s)"'"
      imageName: "'"${IMAGE}"'"
      gpuCount: 1
      gpuTypeId: "NVIDIA '"${GPU//_/ }"'"
      containerDiskInGb: 50
      env: [{ key: "AGENT_PROFILE", value: "'"${WORKLOAD}"'" }]
    }) { id desiredStatus } }'
    curl -sfS "${RUNPOD_ENDPOINT}" \
      -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$(jq -nc --arg q "${QUERY}" '{query: $q}')" | jq .
    ;;
  teardown)
    echo "RunPod teardown: terminate pods via console or GraphQL podTerminate"
    ;;
  *) echo "usage: $0 [launch|teardown]"; exit 1 ;;
esac

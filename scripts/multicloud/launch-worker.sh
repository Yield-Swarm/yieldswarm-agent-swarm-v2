#!/usr/bin/env bash
# Route workload launch to a cloud provider.
#
# Usage:
#   PROVIDER=akash WORKLOAD=bittensor ./scripts/multicloud/launch-worker.sh
#   PROVIDER=vast WORKLOAD=training GPU=RTX_4090 ./scripts/multicloud/launch-worker.sh
#   PROVIDER=runpod WORKLOAD=inference ./scripts/multicloud/launch-worker.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"

PROVIDER="${PROVIDER:-}"
WORKLOAD="${WORKLOAD:-inference}"
GPU="${GPU:-RTX_3090}"
DRY_RUN="${DRY_RUN:-0}"

log() { echo "[multicloud-launch] $*"; }
die() { log "ERROR: $*"; exit 1; }

[[ -n "${PROVIDER}" ]] || die "set PROVIDER=akash|vast|runpod|azure|gcp|aws|alibaba"

PROVIDER_SCRIPT="${SCRIPT_DIR}/providers/${PROVIDER}.sh"
[[ -x "${PROVIDER_SCRIPT}" ]] || die "provider script missing: ${PROVIDER_SCRIPT}"

mkdir -p "${RUN_DIR}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RECORD="${RUN_DIR}/multicloud-launch-${PROVIDER}-${STAMP}.json"

log "provider=${PROVIDER} workload=${WORKLOAD} gpu=${GPU} dry_run=${DRY_RUN}"

export WORKLOAD GPU DRY_RUN
RESULT="$("${PROVIDER_SCRIPT}" launch 2>&1)" || {
  log "launch failed: ${RESULT}"
  exit 1
}

jq -nc \
  --arg provider "${PROVIDER}" \
  --arg workload "${WORKLOAD}" \
  --arg gpu "${GPU}" \
  --arg ts "${STAMP}" \
  --arg result "${RESULT}" \
  '{provider:$provider, workload:$workload, gpu:$gpu, launched_at:$ts, result:$result}' \
  > "${RECORD}"

log "saved ${RECORD}"
echo "${RESULT}"

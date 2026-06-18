#!/usr/bin/env bash
# deploy/templates/cloud/vast/deploy.sh — Vast.ai on-demand OpenClaw mining instance
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

[[ -f .env ]] && set -a && source .env && set +a

: "${VAST_API_KEY:?Set VAST_API_KEY in .env}"
IMAGE="${OPENCLAW_IMAGE:-${VAST_IMAGE:-ghcr.io/yield-swarm/openclaw-miner:latest}}"
GPU="${VAST_GPU_MODEL:-RTX_4090}"
DISK="${VAST_DISK_GB:-200}"
IDX="${OPENCLAW_INSTANCE_INDEX:-0}"
ONSTART="${VAST_ONSTART:-/app/entrypoint.mining.sh}"

log() { printf '[vast-deploy] %s\n' "$*"; }

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  log "[dry-run] would create Vast instance gpu=$GPU image=$IMAGE idx=$IDX"
  exit 0
fi

# Vast API v0 — search offers then create instance
OFFER_ID="${VAST_OFFER_ID:-}"
if [[ -z "$OFFER_ID" ]]; then
  log "searching offers for $GPU..."
  OFFER_ID=$(curl -sf "https://console.vast.ai/api/v0/bundles/?q=${GPU}" \
    -H "Authorization: Bearer ${VAST_API_KEY}" \
    | jq -r '.offers[0].id // empty')
fi

if [[ -z "$OFFER_ID" ]]; then
  log "ERROR: no Vast offer found — set VAST_OFFER_ID manually"
  exit 1
fi

log "creating instance from offer $OFFER_ID"
RESP=$(curl -sf -X PUT "https://console.vast.ai/api/v0/asks/${OFFER_ID}/" \
  -H "Authorization: Bearer ${VAST_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(jq -nc \
    --arg img "$IMAGE" \
    --arg onstart "$ONSTART" \
    --argjson disk "$DISK" \
    '{image:$img, disk_space:$disk, onstart:$onstart, env:{OPENCLAW_INSTANCE_INDEX:"'"$IDX"'",CLOUD_PROVIDER:"vast"}}')")

echo "$RESP" | jq .
INSTANCE_ID=$(echo "$RESP" | jq -r '.new_contract // .id // empty')
log "instance created: $INSTANCE_ID"
echo "$INSTANCE_ID" >>"${ROOT}/.run/vast-instances.txt"

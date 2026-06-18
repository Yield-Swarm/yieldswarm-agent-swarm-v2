#!/usr/bin/env bash
# deploy/full-stack-mining-scale.sh — Scale OpenClaw mining 50–400+ instances (credit-burn)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${MINING_SCALE_TARGET:-50}"
BATCH="${MINING_SCALE_BATCH:-10}"
MAX="${MINING_SCALE_MAX:-400}"
PROVIDER="${CLOUD_PROVIDER:-vast}"
DRY_RUN="${DRY_RUN:-0}"
ROLLBACK_ON_FAIL="${ROLLBACK_ON_FAIL:-1}"

if [[ -f .env ]]; then set -a; source .env; set +a; fi

log() { printf '[mining-scale] %s\n' "$*"; }

deploy_batch() {
  local start="$1" count="$2"
  local i
  for i in $(seq "$start" $((start + count - 1))); do
    [[ "$i" -gt "$MAX" ]] && break
    export OPENCLAW_INSTANCE_INDEX="$i"
    export INSTANCE_ID="openclaw-scale-${i}"
    if [[ "$DRY_RUN" == "1" ]]; then
      log "[dry-run] instance $i"
      continue
    fi
    case "${PROVIDER,,}" in
      vast) OPENCLAW_INSTANCE_INDEX="$i" bash deploy/templates/cloud/vast/deploy.sh || {
        log "FAIL instance $i"; [[ "$ROLLBACK_ON_FAIL" == "1" ]] && exit 1; }
        ;;
      akash)
        OPENCLAW_INSTANCE_INDEX="$i" OPENCLAW_TEST_COUNT=1 bash deploy/deploy-openclaw-test.sh || true
        ;;
      *) log "unsupported provider $PROVIDER"; exit 1 ;;
    esac
    sleep 1
  done
}

preflight() {
  log "preflight target=$TARGET max=$MAX provider=$PROVIDER batch=$BATCH"
  bash scripts/profitability-tracker-pure-credit.sh | jq '.projection.creditRunwayDaysAtCurrentBurn' || true
  if [[ "${MINING_ENABLED:-1}" != "1" ]]; then
    log "MINING_ENABLED=0 — abort"
    exit 1
  fi
}

main() {
  preflight
  local deployed=0
  while [[ "$deployed" -lt "$TARGET" && "$deployed" -lt "$MAX" ]]; do
    local batch_size="$BATCH"
    if (( deployed + batch_size > TARGET )); then
      batch_size=$((TARGET - deployed))
    fi
    log "batch deploy $((deployed + 1))..$((deployed + batch_size))"
    deploy_batch $((deployed + 1)) "$batch_size"
    deployed=$((deployed + batch_size))
    bash scripts/profitability-tracker-pure-credit.sh >/dev/null || true
    sleep 5
  done
  log "scale complete deployed=$deployed"
}

main "$@"

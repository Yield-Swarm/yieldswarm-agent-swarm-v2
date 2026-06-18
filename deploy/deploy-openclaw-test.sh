#!/usr/bin/env bash
# deploy/deploy-openclaw-test.sh — Deploy 5-instance pure-credit mining test (~$50 credits)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COUNT="${OPENCLAW_TEST_COUNT:-5}"
PROVIDER="${CLOUD_PROVIDER:-vast}"
IMAGE="${OPENCLAW_IMAGE:-ghcr.io/yield-swarm/openclaw-miner:latest}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -f .env ]]; then set -a; source .env; set +a
elif [[ -f deploy/config.env ]]; then set -a; source deploy/config.env; set +a
fi

log() { printf '[openclaw-test] %s\n' "$*"; }

render_sdl() {
  chmod +x deploy/templates/lib/render-template.sh 2>/dev/null || true
  if [[ -f deploy/templates/lib/render-template.sh ]]; then
    OPENCLAW_IMAGE="$IMAGE" ./deploy/templates/lib/render-template.sh openclaw
  fi
}

deploy_one() {
  local idx="$1"
  export OPENCLAW_INSTANCE_INDEX="$idx"
  export INSTANCE_ID="openclaw-test-${idx}"
  export CLOUD_PROVIDER="$PROVIDER"

  log "instance $idx/$COUNT provider=$PROVIDER"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would deploy instance $idx"
    return 0
  fi

  case "${PROVIDER,,}" in
    vast)
      OPENCLAW_INSTANCE_INDEX="$idx" bash deploy/templates/cloud/vast/deploy.sh
      ;;
    akash)
      render_sdl
      SDL="${ROOT}/deploy/rendered/cloud/akash/openclaw.sdl.yml"
      if [[ -f "$SDL" ]] && command -v provider-services >/dev/null 2>&1; then
        provider-services tx deployment create "$SDL" --from "${AKASH_KEY_NAME:-default}"
      else
        log "SDL or provider-services missing — render only: $SDL"
      fi
      ;;
    runpod)
      log "RunPod: set RUNPOD_API_KEY and use scripts/multicloud/launch-worker.sh PROVIDER=runpod"
      ;;
    *)
      log "unknown provider $PROVIDER — dry local docker"
      docker run -d --rm \
        -e MINING_ENABLED=0 \
        -e CLOUD_PROVIDER="$PROVIDER" \
        -e OPENCLAW_INSTANCE_INDEX="$idx" \
        -e INSTANCE_ID="openclaw-test-${idx}" \
        -p "$((9080 + idx)):8080" \
        "$IMAGE" || true
      ;;
  esac
}

log "OpenClaw 5-instance test — COUNT=$COUNT PROVIDER=$PROVIDER IMAGE=$IMAGE"
for i in $(seq 1 "$COUNT"); do
  deploy_one "$i"
  sleep 2
done

log "Test deploy complete. Track: bash scripts/profitability-tracker-pure-credit.sh"

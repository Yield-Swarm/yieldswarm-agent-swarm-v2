#!/usr/bin/env bash
# Deploy 5 OpenClaw workers as a single Akash deployment (count: 5).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source "${REPO_ROOT}/deploy/scripts/lib.sh"
load_config

NUM_INSTANCES="${NUM_INSTANCES:-5}"
WORKLOAD_MODE="${WORKLOAD_MODE:-dual-yield}"
API_BASE="${API_BASE:-http://127.0.0.1:8080}"
DRY_RUN="${DRY_RUN:-1}"
SDL="${OPENCLAW_AKASH_SDL:-deploy/akash/openclaw-test-5.sdl.yml}"
STATE_DIR="${REPO_ROOT}/deploy/openclaw-test/state"
RENDERED="${REPO_ROOT}/.run/openclaw-test-5.rendered.yml"

mkdir -p "$STATE_DIR" "${REPO_ROOT}/.run"

step() { printf '\n==> %s\n' "$*"; }

render_openclaw_sdl() {
  step "Render Akash SDL ($NUM_INSTANCES replicas)"
  sed \
    -e "s|yieldswarm/openclaw:latest|${OPENCLAW_IMAGE:-yieldswarm/openclaw:latest}|g" \
    -e "s|WORKLOAD_MODE=dual-yield|WORKLOAD_MODE=${WORKLOAD_MODE}|g" \
    -e "s|API_BASE=http://127.0.0.1:8080|API_BASE=${API_BASE}|g" \
    -e "s|count: 5|count: ${NUM_INSTANCES}|g" \
    "${REPO_ROOT}/${SDL}" > "$RENDERED"
  ok "Rendered -> $RENDERED"
  cp "$RENDERED" "${REPO_ROOT}/deploy/akash/openclaw-test-5.live.yml"
}

record_akash_state() {
  local dseq="${1:-unknown}"
  local provider="${2:-unknown}"
  local uris="${3:-}"
  : > "${STATE_DIR}/instances.jsonl"
  local i
  for i in $(seq 1 "$NUM_INSTANCES"); do
    echo "{\"instance\":$i,\"provider\":\"akash\",\"dseq\":\"$dseq\",\"akash_provider\":\"$provider\",\"workload_mode\":\"$WORKLOAD_MODE\",\"status\":\"deployed\",\"uris\":\"$uris\"}" \
      >> "${STATE_DIR}/instances.jsonl"
  done
  ok "State -> ${STATE_DIR}/instances.jsonl ($NUM_INSTANCES lines)"
}

step "Akash OpenClaw test fleet (count=$NUM_INSTANCES mode=$WORKLOAD_MODE)"

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] would deploy $NUM_INSTANCES OpenClaw replicas via $SDL"
  render_openclaw_sdl
  record_akash_state "dry-run" "dry-run" ""
  echo ""
  log "Live deploy: DRY_RUN=0 CLOUD_PROVIDER=akash ./deploy/akash/deploy-openclaw-test-akash.sh"
  exit 0
fi

command -v provider-services >/dev/null 2>&1 || command -v akash >/dev/null 2>&1 || {
  die "Akash CLI required (provider-services or akash)"
}

render_openclaw_sdl
export AKASH_SDL="deploy/akash/openclaw-test-5.live.yml"

step "Create Akash lease (single deployment, count=$NUM_INSTANCES)"
bash "${REPO_ROOT}/deploy/akash/create-lease.sh"

LEASE_ENV="${REPO_ROOT}/.run/akash-lease.env"
# shellcheck disable=SC1090
[[ -f "$LEASE_ENV" ]] && source "$LEASE_ENV"

record_akash_state "${AKASH_DSEQ:-}" "${AKASH_PROVIDER:-}" "${AKASH_WORKER_URLS:-}"

step "Verify profitability API"
curl -sf "${API_BASE}/api/treasury/pow-yield" | head -c 400 || warn "start backend for /api/treasury/pow-yield"

ok "Akash OpenClaw test fleet deployed (dseq=${AKASH_DSEQ:-?})"
echo "  Monitor: ./deploy/openclaw/monitor-instances.sh"
echo "  Dashboard: ${API_BASE}/pow-yield"

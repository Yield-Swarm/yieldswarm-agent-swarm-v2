#!/usr/bin/env bash
# =============================================================================
# YieldSwarm OpenClaw Test Deployment — 5 instances @ ~$50 cloud credit budget
#
# Deploys OpenClaw worker nodes for validation before scaling deploy-full-stack.sh.
#
# Workload modes (WORKLOAD_MODE):
#   openclaw     — default: agent worker + telemetry (recommended)
#   dual-yield   — GPU Bittensor track + CPU DePIN/Grass (repo-native dual path)
#   pow-dual     — BLOCKED unless OPENCLAW_ALLOW_POW=1 + provider in allowlist
#                  (operator must verify provider ToS; configs are .example only)
#
# Usage:
#   DRY_RUN=1 ./deploy/deploy-openclaw-test.sh
#   CLOUD_PROVIDER=vast ./deploy/deploy-openclaw-test.sh
#   CLOUD_PROVIDER=akash WORKLOAD_MODE=dual-yield ./deploy/deploy-openclaw-test.sh
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source "${REPO_ROOT}/deploy/scripts/lib.sh"
load_config

NUM_INSTANCES="${NUM_INSTANCES:-5}"
BUDGET_USD="${OPENCLAW_TEST_BUDGET_USD:-50}"
COST_PER_INSTANCE_USD="${OPENCLAW_COST_PER_INSTANCE_USD:-10}"
CLOUD_PROVIDER="${CLOUD_PROVIDER:-vast}"
WORKLOAD_MODE="${WORKLOAD_MODE:-openclaw}"
DRY_RUN="${DRY_RUN:-1}"
POW_ALLOWLIST="${OPENCLAW_POW_PROVIDER_ALLOWLIST:-vast,runpod}"

step() { printf '\n==> %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*" >&2; }

estimated_cost() {
  echo "$(( NUM_INSTANCES * COST_PER_INSTANCE_USD ))"
}

validate_env() {
  step "Validate environment (provider=$CLOUD_PROVIDER mode=$WORKLOAD_MODE)"
  local est
  est="$(estimated_cost)"
  log "Instances: $NUM_INSTANCES | Est. cost: \$$est / budget: \$$BUDGET_USD"
  if (( est > BUDGET_USD )); then
    warn "Estimated cost \$$est exceeds budget \$$BUDGET_USD — reduce NUM_INSTANCES or COST_PER_INSTANCE_USD"
  fi

  case "$CLOUD_PROVIDER" in
    vast)
      [[ -n "${VAST_API_KEY:-}" ]] || {
        warn "VAST_API_KEY not set — use DRY_RUN=1 or add key to .env.local"
        [[ "$DRY_RUN" == "1" ]] || exit 1
      }
      ;;
    akash)
      command -v provider-services >/dev/null 2>&1 || {
        warn "provider-services CLI not found (Akash)"
        [[ "$DRY_RUN" == "1" ]] || exit 1
      }
      ;;
    *)
      warn "Provider $CLOUD_PROVIDER — scaffold only; use vast or akash for live deploy"
      ;;
  esac

  if [[ "$WORKLOAD_MODE" == "pow-dual" ]]; then
    if [[ "${OPENCLAW_ALLOW_POW:-0}" != "1" ]]; then
      err "pow-dual blocked: set OPENCLAW_ALLOW_POW=1 after verifying provider ToS"
      exit 1
    fi
    if ! echo ",$POW_ALLOWLIST," | grep -q ",$CLOUD_PROVIDER,"; then
      err "pow-dual not allowed on provider $CLOUD_PROVIDER (allowlist: $POW_ALLOWLIST)"
      exit 1
    fi
    warn "pow-dual: operator responsible for provider ToS compliance"
    [[ -n "${XMR_WALLET:-}" && -n "${KAS_WALLET:-}" ]] || warn "XMR_WALLET / KAS_WALLET not set"
  fi
}

prepare_configs() {
  step "Prepare OpenClaw test configs"
  mkdir -p deploy/openclaw-test/config deploy/openclaw-test/state

  cat > deploy/openclaw-test/config/worker.env <<EOF
WORKER_ROLE=openclaw-gpu
WORKLOAD_MODE=${WORKLOAD_MODE}
NUM_INSTANCES=${NUM_INSTANCES}
API_BASE=${API_BASE:-http://127.0.0.1:8080}
TEMP_THRESHOLD_CELSIUS=${TEMP_THRESHOLD_CELSIUS:-83}
HEARTBEAT_INTERVAL_SECONDS=${HEARTBEAT_INTERVAL_SECONDS:-420}
POW_MINING_COINS=${POW_MINING_COINS:-bittensor,grass,kaspa}
EOF

  # Example-only mining configs (not used by default image — verify ToS before use)
  if [[ ! -f deploy/openclaw-test/config/xmrig.json.example ]]; then
    cat > deploy/openclaw-test/config/xmrig.json.example <<'EOF'
{
  "autosave": true,
  "cpu": { "enabled": true, "huge-pages": true, "priority": 5 },
  "pools": [{ "url": "POOL_URL", "user": "WALLET", "pass": "x", "rig-id": "openclaw-test" }]
}
EOF
  fi
  ok "configs in deploy/openclaw-test/config/"
}

build_image() {
  step "Build OpenClaw worker image"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] docker build -t yieldswarm/openclaw:latest -f deploy/Dockerfile.openclaw ."
    return
  fi
  docker build -t yieldswarm/openclaw:latest -f deploy/Dockerfile.openclaw .
  ok "image yieldswarm/openclaw:latest"
}

deploy_vast_instance() {
  local idx="$1"
  local gpu="${VAST_GPU_MODEL:-RTX_4090}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] vast instance #$idx gpu=$gpu mode=$WORKLOAD_MODE"
    echo "{\"instance\":$idx,\"provider\":\"vast\",\"status\":\"dry-run\"}" \
      >> deploy/openclaw-test/state/instances.jsonl
    return
  fi

  if [[ -x scripts/multicloud/providers/vast.sh ]]; then
  DRY_RUN=0 GPU="$gpu" bash scripts/multicloud/providers/vast.sh launch || true
  fi

  # Vast API v0 — create from cheapest matching offer when CLI unavailable
  local api="${VAST_API:-https://console.vast.ai/api/v0}"
  local offers
  offers="$(curl -sfS "${api}/bundles/?q=%7B%22gpu_name%22%3A%7B%22eq%22%3A%22${gpu}%22%7D%7D" \
    -H "Authorization: Bearer ${VAST_API_KEY}" 2>/dev/null || echo '{}')"
  local offer_id
  offer_id="$(echo "$offers" | jq -r '.offers[0].id // empty' 2>/dev/null || true)"
  if [[ -z "$offer_id" ]]; then
    warn "No Vast offer found for $gpu — instance #$idx skipped"
    return
  fi

  local onstart="cd /app && ./deploy/openclaw/entrypoint.sh"
  local payload
  payload="$(jq -n \
    --arg img "yieldswarm/openclaw:latest" \
    --arg onstart "$onstart" \
    --arg mode "$WORKLOAD_MODE" \
    --arg api "${API_BASE:-http://127.0.0.1:8080}" \
    '{
      client_id: "yieldswarm-openclaw-test",
      image: $img,
      onstart: $onstart,
      env: ("WORKLOAD_MODE=" + $mode + " API_BASE=" + $api)
    }')"

  local resp
  resp="$(curl -sfS -X PUT "${api}/asks/${offer_id}/" \
    -H "Authorization: Bearer ${VAST_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null || echo '{}')"
  echo "$resp" | jq -c '{instance:'"$idx"',provider:"vast",new_contract:.new_contract}' \
    >> deploy/openclaw-test/state/instances.jsonl 2>/dev/null || \
    echo "{\"instance\":$idx,\"provider\":\"vast\",\"raw\":$(echo "$resp" | jq -c . 2>/dev/null || echo null)}" \
    >> deploy/openclaw-test/state/instances.jsonl
  ok "vast instance #$idx requested (offer $offer_id)"
}

deploy_akash_fleet() {
  step "Deploy Akash fleet ($NUM_INSTANCES replicas, single deployment)"
  bash "${REPO_ROOT}/deploy/akash/deploy-openclaw-test-akash.sh"
}

deploy_instances() {
  step "Deploy $NUM_INSTANCES OpenClaw instances on $CLOUD_PROVIDER"
  : > deploy/openclaw-test/state/instances.jsonl
  local i
  for i in $(seq 1 "$NUM_INSTANCES"); do
    log "→ instance #$i"
    case "$CLOUD_PROVIDER" in
      vast) deploy_vast_instance "$i" ;;
      akash)
        if [[ "$i" -eq 1 ]]; then deploy_akash_fleet; fi
        ;;
      *) log "[scaffold] instance #$i on $CLOUD_PROVIDER" ;;
    esac
    sleep 2
  done
}

print_next_steps() {
  step "Deployment complete"
  cat <<EOF

OpenClaw test: $NUM_INSTANCES instances | mode=$WORKLOAD_MODE | provider=$CLOUD_PROVIDER
State log: deploy/openclaw-test/state/instances.jsonl

Monitor:
  ./deploy/openclaw/monitor-instances.sh

Telemetry:
  curl ${API_BASE:-http://127.0.0.1:8080}/api/helix/status
  curl ${API_BASE:-http://127.0.0.1:8080}/api/arena/overview

After 24h validation → scale via deploy/deploy-full-stack.sh PHASE=2

EOF
  if [[ "$DRY_RUN" == "1" ]]; then
    warn "DRY_RUN=1 — no live instances created. Run: DRY_RUN=0 ./deploy/deploy-openclaw-test.sh"
  fi
}

validate_env
prepare_configs
build_image
deploy_instances
print_next_steps

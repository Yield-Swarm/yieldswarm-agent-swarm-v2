#!/usr/bin/env bash
# =============================================================================
# Cheap RTX GPU pool — Azure + Akash + Vast + RunPod under $0.40/hr
#
# Target: ~$300 total spend on consumer RTX (3060–4090) at <= $0.40/hr
#
# Usage:
#   cp deploy/env/gpu-pool.env.example deploy/env/gpu-pool.env
#   source deploy/env/gpu-pool.env
#   ./scripts/gpu-pool/launch-cheap-rtx.sh              # dry-run plan
#   GPU_POOL_DRY_RUN=0 ./scripts/gpu-pool/launch-cheap-rtx.sh
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
mkdir -p .run reports

[[ -f deploy/env/gpu-pool.env ]] && set -a && source deploy/env/gpu-pool.env && set +a
[[ -f deploy/env/trident-mainnet.env ]] && set -a && source deploy/env/trident-mainnet.env && set +a
[[ -f .env ]] && set -a && source .env && set +a

BUDGET="${GPU_POOL_BUDGET_USD:-300}"
MAX_HR="${GPU_MAX_PRICE_PER_HOUR:-0.40}"
DRY="${GPU_POOL_DRY_RUN:-1}"
MODELS="${GPU_TARGET_MODELS:-RTX_3060,RTX_3070,RTX_3080,RTX_3090,RTX_4060,RTX_4070}"
OUT=".run/gpu-pool-allocation.json"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

log() { printf '[gpu-pool] %s\n' "$*" >&2; }

MAX_HOURS="$(python3 -c "print(round(${BUDGET}/${MAX_HR},2))")"
log "Budget \$${BUDGET} @ max \$${MAX_HR}/hr → ~${MAX_HOURS} GPU-hours"
log "dry_run=${DRY}"

IFS=',' read -ra GPU_LIST <<< "$MODELS"

# --- Provider offer collectors ------------------------------------------------
collect_vast() {
  command -v curl >/dev/null 2>&1 || return 0
  [[ -n "${VAST_API_KEY:-}" ]] || { echo '[]'; return 0; }
  local offers="[]"
  for gpu in "${GPU_LIST[@]}"; do
    local q
    q="$(python3 -c "import urllib.parse; print(urllib.parse.quote('{\"gpu_name\":{\"eq\":\"'+'${gpu}'+'\"}}'))")"
    local chunk
    chunk="$(curl -sfS "https://console.vast.ai/api/v0/bundles/?q=${q}" \
      -H "Authorization: Bearer ${VAST_API_KEY}" 2>/dev/null \
      | jq --arg max "${MAX_HR}" --arg gpu "${gpu}" '
        [.offers[]? | select((.dph_total // 999) <= ($max|tonumber)) |
          {provider:"vast", gpu:$gpu, price_per_hr:.dph_total, id:.id, num_gpus:(.num_gpus//1)}]
      ' 2>/dev/null || echo '[]')"
    offers="$(jq -s 'add' <(echo "$offers") <(echo "$chunk"))"
  done
  echo "$offers" | jq 'sort_by(.price_per_hr) | .[:20]'
}

collect_runpod() {
  [[ -n "${RUNPOD_API_KEY:-}" ]] || { echo '[]'; return 0; }
  local query='query { gpuTypes { id displayName memoryInGb lowestPrice { minimumBidPrice uninterruptablePrice } } }'
  curl -sfS https://api.runpod.io/graphql \
    -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg q "$query" '{query:$q}')" 2>/dev/null \
    | jq --arg max "${MAX_HR}" '
      [.data.gpuTypes[]? |
        select(.displayName | test("RTX";"i")) |
        {provider:"runpod", gpu:.displayName, price_per_hr:(.lowestPrice.uninterruptablePrice // .lowestPrice.minimumBidPrice // 999), id:.id}
        | select(.price_per_hr <= ($max|tonumber))]
      | sort_by(.price_per_hr) | .[:20]' 2>/dev/null || echo '[]'
}

collect_akash() {
  command -v provider-services >/dev/null 2>&1 || { echo '[]'; return 0; }
  [[ -n "${AKASH_KEY_NAME:-}" ]] || { echo '[]'; return 0; }
  # Akash market: list bids under max uakt (rough proxy — refine with live bids)
  local max_uakt="${AKASH_MAX_BID_PRICE:-400000}"
  echo "[{\"provider\":\"akash\",\"gpu\":\"RTX_3090\",\"price_per_hr_est\":0.25,\"note\":\"deploy via SDL bid <= ${max_uakt}uakt\",\"sdl\":\"deploy/akash-bittensor-miner.sdl.yml\"}]"
}

plan_allocation() {
  local vast runpod akash merged
  log "Scanning Vast.ai..."
  vast="$(collect_vast)"
  log "Scanning RunPod..."
  runpod="$(collect_runpod)"
  log "Scanning Akash..."
  akash="$(collect_akash)"

  merged="$(jq -s 'add | sort_by(.price_per_hr) | .[:50]' <(echo "$vast") <(echo "$runpod") <(echo "$akash"))"

  local remaining="${BUDGET}"
  local hours=0
  local picks="[]"

  while read -r line; do
  [[ -z "$line" ]] && continue
    local price provider gpu
    price="$(echo "$line" | jq -r '.price_per_hr')"
    provider="$(echo "$line" | jq -r '.provider')"
    gpu="$(echo "$line" | jq -r '.gpu')"
    local afford
    afford="$(python3 -c "import math; print(int(${remaining}/float(${price})))" 2>/dev/null || echo 0)"
    [[ "$afford" -gt 0 ]] || continue
    local take=1
    [[ "$afford" -gt 24 ]] && take=24
    local cost
    cost="$(python3 -c "print(round(${take}*float(${price}),2))")"
    remaining="$(python3 -c "print(round(${remaining}-${cost},2))")"
    hours="$(python3 -c "print(${hours}+${take})")"
    picks="$(jq --argjson o "$line" --argjson h "$take" --argjson c "$cost" \
      '. + [$o + {planned_hours:$h, planned_cost_usd:$c}]' <<< "$picks")"
    [[ "$(python3 -c "print(1 if ${remaining} < ${MAX_HR} else 0)")" == "1" ]] && break
  done < <(echo "$merged" | jq -c '.[]')

  jq -nc \
    --arg ts "$STAMP" \
    --argjson budget "$BUDGET" \
    --argjson max_hr "$MAX_HR" \
    --argjson dry "$DRY" \
    --argjson offers "$merged" \
    --argjson picks "$picks" \
    --argjson hours "$hours" \
    '{
      generated_at: $ts,
      budget_usd: $budget,
      max_price_per_hr: $max_hr,
      dry_run: ($dry == 1),
      max_gpu_hours: ($budget / $max_hr),
      planned_gpu_hours: $hours,
      offers_under_max: $offers,
      allocation: $picks
    }' | tee "$OUT"
}

launch_picks() {
  local plan="$1"
  echo "$plan" | jq -c '.allocation[]?' | while read -r pick; do
    local provider gpu
    provider="$(echo "$pick" | jq -r '.provider')"
    gpu="$(echo "$pick" | jq -r '.gpu')"
    log "Launch ${provider} ${gpu}..."
    case "$provider" in
      akash)
        export AKASH_SDL="${AKASH_SDL:-deploy/akash-bittensor-miner.sdl.yml}"
        export AUTO_SELECT_BID=1
        bash scripts/deploy-to-akash.sh deploy "${AKASH_SDL}" || log "WARN: akash launch failed"
        ;;
      vast)
        PROVIDER=vast GPU="$gpu" DRY_RUN=0 bash scripts/multicloud/launch-worker.sh || log "WARN: vast launch failed"
        ;;
      runpod)
        PROVIDER=runpod GPU="$gpu" DRY_RUN=0 bash scripts/multicloud/launch-worker.sh || log "WARN: runpod launch failed"
        ;;
      *) log "skip unknown provider ${provider}" ;;
    esac
  done
}

PLAN="$(plan_allocation)"
log "Wrote ${OUT}"

if [[ "$DRY" == "0" ]]; then
  log "LIVE launch — spending up to \$${BUDGET}"
  launch_picks "$PLAN"
else
  log "Dry-run only — set GPU_POOL_DRY_RUN=0 to launch"
  echo "$PLAN" | jq '{planned_gpu_hours, allocation: [.allocation[]? | {provider,gpu,price_per_hr,planned_hours,planned_cost_usd}]}'
fi

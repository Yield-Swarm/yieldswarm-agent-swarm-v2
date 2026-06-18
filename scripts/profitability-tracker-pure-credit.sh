#!/usr/bin/env bash
# scripts/profitability-tracker-pure-credit.sh — Real-time credit-burn mining profitability
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

API_BASE="${YIELDSWARM_API_BASE:-http://127.0.0.1:8080/api}"
METRICS_FILE="${MINING_METRICS_FILE:-.run/mining-profit.jsonl}"
INSTANCE_COST_USD="${OPENCLAW_INSTANCE_COST_USD:-10}"
INSTANCE_COUNT="${OPENCLAW_INSTANCE_COUNT:-5}"
XMR_USD="${XMR_USD_PRICE:-165}"
KAS_USD="${KAS_USD_PRICE:-0.12}"
CREDIT_BALANCE_USD="${CLOUD_CREDIT_BALANCE_USD:-3850}"

log() { printf '[profit-tracker] %s\n' "$*"; }

fetch_api() {
  curl -sf "${API_BASE}/mining/summary" 2>/dev/null || echo '{}'
}

aggregate_local() {
  local f="${1:-.run/mining/metrics.jsonl}"
  [[ -f "$f" ]] || { echo '{"instances":0}'; return; }
  python3 - <<PY
import json
from pathlib import Path
p = Path("$f")
rows = [json.loads(l) for l in p.read_text().splitlines() if l.strip()]
print(json.dumps({"instances": len(rows), "avgTempC": sum(r.get("tempC",0) for r in rows)/max(len(rows),1)}))
PY
}

project_monthly() {
  local daily_low daily_high
  daily_low=$(awk -v n="$INSTANCE_COUNT" 'BEGIN { printf "%.2f", n * 3.50 }')
  daily_high=$(awk -v n="$INSTANCE_COUNT" 'BEGIN { printf "%.2f", n * 8.00 }')
  local monthly_low monthly_high
  monthly_low=$(awk -v d="$daily_low" 'BEGIN { printf "%.0f", d * 30 }')
  monthly_high=$(awk -v d="$daily_high" 'BEGIN { printf "%.0f", d * 30 }')
  local credit_days
  credit_days=$(awk -v c="$CREDIT_BALANCE_USD" -v cost="$INSTANCE_COST_USD" -v n="$INSTANCE_COUNT" \
    'BEGIN { if (n*cost<=0) print 0; else print int(c/(n*cost)*30) }')

  cat <<EOF
{
  "instanceCount": $INSTANCE_COUNT,
  "instanceCostUsdPerMonth": $INSTANCE_COST_USD,
  "creditBalanceUsd": $CREDIT_BALANCE_USD,
  "projectedDailyUsd": { "low": $daily_low, "high": $daily_high },
  "projectedMonthlyUsd": { "low": $monthly_low, "high": $monthly_high },
  "creditRunwayDaysAtCurrentBurn": $credit_days,
  "assumptions": {
    "powerCostUsd": 0,
    "xmrUsd": $XMR_USD,
    "kasUsd": $KAS_USD,
    "strategy": "CPU XMR + GPU KAS/Bittensor pure-credit arbitrage"
  }
}
EOF
}

main() {
  mkdir -p "$(dirname "$METRICS_FILE")"
  local api local summary ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  api="$(fetch_api)"
  local="$(aggregate_local)"
  summary="$(jq -nc --arg ts "$ts" --argjson api "$api" --argjson local "$local" \
    --argjson proj "$(project_monthly)" \
    '{timestamp:$ts, api:$api, local:$local, projection:$proj}')"

  echo "$summary" | tee -a "$METRICS_FILE"
  echo "$summary" | jq '.projection'
}

main "$@"

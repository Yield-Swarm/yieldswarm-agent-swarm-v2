#!/usr/bin/env bash
# Monitor OpenClaw test instances — reads state log + polls telemetry API.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="${REPO_ROOT}/deploy/openclaw-test/state/instances.jsonl"
API_BASE="${API_BASE:-http://127.0.0.1:8080}"

echo "OpenClaw Test Monitor"
echo "====================="
echo "API: $API_BASE"
echo ""

if [[ -f "$STATE" ]]; then
  echo "Deployed instances:"
  cat "$STATE" | jq -c . 2>/dev/null || cat "$STATE"
  echo ""
else
  echo "No state file yet: $STATE"
  echo "Run: ./deploy/deploy-openclaw-test.sh"
  echo ""
fi

echo "Helix / Arena snapshot:"
curl -sf "${API_BASE}/api/helix/status" 2>/dev/null \
  | jq '{activated,phase,readinessScore,tracks}' 2>/dev/null \
  || echo "  (backend not reachable)"

curl -sf "${API_BASE}/api/treasury/pow-yield" 2>/dev/null \
  | jq '{mode:.workload_mode,instances:.instance_count,net:.totals.estimated_daily_net_usd}' 2>/dev/null \
  || echo "  (pow-yield API not reachable — start backend)"

echo ""
echo "Dashboard: ${API_BASE}/pow-yield"
echo "Re-run: watch -n 60 $0"

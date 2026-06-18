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

curl -sf "${API_BASE}/api/arena/overview" 2>/dev/null \
  | jq '{helix:.helix, workers:(.akash.workers|length)}' 2>/dev/null \
  || true

echo ""
echo "Thermal guard: deploy/entrypoint.monitor.sh @ ${TEMP_THRESHOLD_CELSIUS:-83}°C"
echo "Re-run: watch -n 60 $0"

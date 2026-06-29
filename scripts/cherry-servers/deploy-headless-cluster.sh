#!/usr/bin/env bash
# Cherry Servers bare-metal headless cluster deploy (90-day sponsorship).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

: "${CHERRY_SERVERS_API_KEY:?Set CHERRY_SERVERS_API_KEY}"
: "${CHERRY_SERVERS_PROJECT_ID:?Set CHERRY_SERVERS_PROJECT_ID}"

NODE_COUNT="${CHERRY_HEADLESS_NODE_COUNT:-4}"
AGENT_COUNT="${CHERRY_AGENT_INSTANCE_COUNT:-10080}"
PLAN="${CHERRY_SERVERS_BARE_METAL_PLAN:-AMD_EPYC}"
REGION="${CHERRY_SERVERS_REGION:-EU}"
API_BASE="${CHERRY_SERVERS_API_BASE:-https://api.cherryservers.com/v1}"

echo "=== Cherry Servers Headless Deploy ==="
echo "Sponsorship active: ${CHERRY_SERVERS_SPONSORSHIP_ACTIVE:-true}"
echo "Days remaining:     ${CHERRY_SERVERS_DAYS_REMAINING:-90}"
echo "Nodes:              $NODE_COUNT"
echo "Agent instances:    $AGENT_COUNT"
echo "Plan:               $PLAN"
echo "Region:             $REGION"
echo ""
echo "Route cloud compute: ${ROUTE_CLOUD_COMPUTE_TO:-CHERRY_SERVERS_BARE_METAL}"
echo "Disable RunPod mining: ${DISABLE_RUNPOD_MINING:-true}"
echo ""
echo "Next: configure CHERRY_SERVERS_API_KEY and run with DRY_RUN=false"
echo "API docs: https://api.cherryservers.com/doc/"

if [[ "${DRY_RUN:-true}" == "true" ]]; then
  echo "[dry-run] Would POST $API_BASE/projects/$CHERRY_SERVERS_PROJECT_ID/servers"
  exit 0
fi

curl -sf -X GET \
  -H "Authorization: Bearer ${CHERRY_SERVERS_API_KEY}" \
  -H "Content-Type: application/json" \
  "${API_BASE}/projects/${CHERRY_SERVERS_PROJECT_ID}/servers" | head -c 500
echo ""
echo "Cherry Servers API reachable."

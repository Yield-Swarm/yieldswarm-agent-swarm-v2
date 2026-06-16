#!/usr/bin/env bash
# =============================================================================
# multicloud-cost-report.sh — Daily utilization + spend snapshot
#
# Usage:
#   ./scripts/multicloud-cost-report.sh
#   ./scripts/multicloud-cost-report.sh --json
#
# Writes: .run/multicloud-cost-report.json
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"
JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

log() { echo "[multicloud-cost-report] $*"; }
mkdir -p "${RUN_DIR}"

# Load budget caps if present
BUDGET_FILE="${REPO_ROOT}/config/multicloud/budgets.env"
if [[ -f "${BUDGET_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${BUDGET_FILE}"
  set +a
fi

MULTICLOUD_DAILY_BUDGET_USD="${MULTICLOUD_DAILY_BUDGET_USD:-50}"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Akash spend estimate ---
AKASH_SPEND_AKT="unknown"
AKASH_SPEND_USD="unknown"
if command -v provider-services >/dev/null 2>&1 && [[ -f "${RUN_DIR}/akash-deploy.json" ]]; then
  DEPLOY_ID="$(jq -r '.deployment_id // .deployment // empty' "${RUN_DIR}/akash-deploy.json" 2>/dev/null || true)"
  if [[ -n "${DEPLOY_ID}" ]]; then
    AKASH_SPEND_AKT="see provider-services query deployment ${DEPLOY_ID}"
  fi
fi

# --- Launch records ---
LAUNCH_COUNT=0
LAUNCH_PROVIDERS=()
for f in "${RUN_DIR}"/multicloud-launch-*.json; do
  [[ -f "$f" ]] || continue
  LAUNCH_COUNT=$((LAUNCH_COUNT + 1))
  prov="$(jq -r '.provider // "unknown"' "$f" 2>/dev/null || echo unknown)"
  LAUNCH_PROVIDERS+=("${prov}")
done

# --- Build report ---
REPORT="$(jq -nc \
  --arg ts "${TS}" \
  --arg daily_budget "${MULTICLOUD_DAILY_BUDGET_USD}" \
  --arg akash_akt "${AKASH_SPEND_AKT}" \
  --argjson launch_count "${LAUNCH_COUNT}" \
  --arg launch_providers "$(IFS=,; echo "${LAUNCH_PROVIDERS[*]:-none}")" \
  '{
    generated_at: $ts,
    daily_budget_usd: ($daily_budget | tonumber),
    providers: {
      akash: { spend_akt: $akash_akt, status: "primary" },
      vast: { status: (if ($launch_providers | test("vast")) then "active" else "idle" end) },
      runpod: { status: (if ($launch_providers | test("runpod")) then "active" else "idle" end) },
      azure: { status: (if ($launch_providers | test("azure")) then "active" else "idle" end) },
      gcp: { status: (if ($launch_providers | test("gcp")) then "active" else "idle" end) }
    },
    launch_records: $launch_count,
    notes: [
      "Set cloud API keys for provider-specific USD estimates",
      "Run daily: make multicloud-cost-report",
      "Tear down idle burst: make multicloud-teardown PROVIDER=vast"
    ]
  }')"

printf '%s' "${REPORT}" | jq '.' > "${RUN_DIR}/multicloud-cost-report.json"

if [[ "${JSON_MODE}" -eq 1 ]]; then
  printf '%s' "${REPORT}" | jq '.'
else
  log "=== Multi-Cloud Cost Report (${TS}) ==="
  printf '%s' "${REPORT}" | jq -r '
    "Daily budget: $\(.daily_budget_usd)",
    "Akash spend: \(.providers.akash.spend_akt)",
    "Launch records: \(.launch_records)",
    "Provider status:",
    (.providers | to_entries[] | "  \(.key): \(.value.status)")
  '
  log "Full report: ${RUN_DIR}/multicloud-cost-report.json"
fi

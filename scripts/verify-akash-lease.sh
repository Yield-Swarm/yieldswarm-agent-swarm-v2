#!/usr/bin/env bash
# =============================================================================
# verify-akash-lease.sh — Post-deploy smoke tests for a live Akash lease
#
# Usage:
#   ./scripts/verify-akash-lease.sh
#   ./scripts/verify-akash-lease.sh https://<lease-uri>:8080
#   ./scripts/verify-akash-lease.sh --json
#
# Reads worker URLs from (in order):
#   1. CLI arguments
#   2. .run/akash-lease.env (AKASH_WORKER_URLS)
#   3. .run/akash-deploy.json (uris[])
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"
LEASE_ENV="${RUN_DIR}/akash-lease.env"
DEPLOY_JSON="${RUN_DIR}/akash-deploy.json"

JSON_MODE=0
TIMEOUT="${VERIFY_TIMEOUT_SECONDS:-20}"
BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8080}"
SOVEREIGN_URL="${SOVEREIGN_URL:-http://127.0.0.1:8765}"

declare -a URLS=()
declare -a RESULTS=()
PASS=0
FAIL=0
WARN=0

log()  { echo "[verify-akash] $*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    http*) URLS+=("${1%/}"); shift ;;
    *) shift ;;
  esac
done

load_urls_from_state() {
  if ((${#URLS[@]} > 0)); then
    return 0
  fi
  if [[ -f "${LEASE_ENV}" ]]; then
    # shellcheck disable=SC1090
    source "${LEASE_ENV}"
    if [[ -n "${AKASH_WORKER_URLS:-}" ]]; then
      IFS=',' read -ra URLS <<< "${AKASH_WORKER_URLS}"
      return 0
    fi
  fi
  if [[ -f "${DEPLOY_JSON}" ]] && command -v jq >/dev/null 2>&1; then
    mapfile -t URLS < <(jq -r '.uris[]? // empty' "${DEPLOY_JSON}")
  fi
}

probe() {
  local name="$1" url="$2" expect="${3:-2xx}"
  local code body
  code="$(curl -sk -o /tmp/verify-akash-body.txt -w '%{http_code}' --max-time "${TIMEOUT}" "${url}" 2>/dev/null || echo "000")"
  body="$(head -c 500 /tmp/verify-akash-body.txt 2>/dev/null || true)"

  local status="fail"
  case "${expect}" in
    2xx) [[ "${code}" =~ ^2 ]] && status="pass" ;;
    any) [[ "${code}" != "000" ]] && status="pass" ;;
    *) [[ "${code}" == "${expect}" ]] && status="pass" ;;
  esac

  RESULTS+=("$(jq -nc --arg name "$name" --arg url "$url" --arg code "$code" --arg status "$status" --arg body "$body" \
    '{name:$name, url:$url, status_code:($code|tonumber), result:$status, body_preview:$body}')")

  case "$status" in
    pass) PASS=$((PASS + 1)); log "PASS ${name} (${code}) ${url}" ;;
    *)    FAIL=$((FAIL + 1)); log "FAIL ${name} (${code}) ${url}" ;;
  esac
}

probe_optional() {
  local name="$1" url="$2"
  local code
  code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time "${TIMEOUT}" "${url}" 2>/dev/null || echo "000")"
  local status="warn"
  [[ "${code}" =~ ^2 ]] && { status="pass"; PASS=$((PASS + 1)); } || { WARN=$((WARN + 1)); }
  RESULTS+=("$(jq -nc --arg name "$name" --arg url "$url" --arg code "$code" --arg status "$status" \
    '{name:$name, url:$url, status_code:($code|tonumber), result:$status}')")
  log "${status^^} ${name} (${code}) ${url}"
}

load_urls_from_state

if ((${#URLS[@]} == 0)); then
  die "no worker URLs — deploy first or pass https://<lease-uri>:8080"
fi

log "verifying ${#URLS[@]} worker URL(s)"

for base in "${URLS[@]}"; do
  base="${base// /}"
  [[ -n "$base" ]] || continue
  base="${base%/}"

  probe "worker-healthz" "${base}/healthz"
  probe "worker-health" "${base}/health" "any"
  probe "worker-telemetry" "${base}/telemetry"
  probe "worker-api-health" "${base}/api/health" "any"
  probe "worker-api-telemetry-akash" "${base}/api/telemetry/akash" "any"
  probe_optional "worker-api-telemetry-odysseus" "${base}/api/telemetry/odysseus"
  probe_optional "kairo-telemetry" "${base}:8091/api/telemetry"
  probe_optional "kairo-health" "${base}:8091/healthz"
  probe_optional "bittensor-axon" "${base}:8091/health"
done

# Local stack probes (optional — warn if not running)
probe_optional "backend-api-health" "${BACKEND_URL}/api/health"
probe_optional "backend-akash-telemetry" "${BACKEND_URL}/api/telemetry/akash"
probe_optional "sovereign-runtime" "${SOVEREIGN_URL}/health"

OVERALL="NO-GO"
[[ "${FAIL}" -eq 0 && "${PASS}" -gt 0 ]] && OVERALL="GO"

if [[ "${JSON_MODE}" -eq 1 ]]; then
  results_json="$(printf '%s\n' "${RESULTS[@]}" | jq -s '.')"
  jq -n \
    --arg overall "${OVERALL}" \
    --argjson pass "${PASS}" \
    --argjson fail "${FAIL}" \
    --argjson warn "${WARN}" \
    --argjson results "$results_json" \
    --argjson urls "$(printf '%s\n' "${URLS[@]}" | jq -R . | jq -s '.')" \
    '{overall:$overall, pass:$pass, fail:$fail, warn:$warn, urls:$urls, checks:$results}'
  [[ "${OVERALL}" == "GO" ]] && exit 0 || exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Akash Lease Verification — ${OVERALL}                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  Pass: ${PASS}  Fail: ${FAIL}  Warn: ${WARN}"
echo ""

if [[ "${OVERALL}" == "GO" ]]; then
  echo "Worker telemetry is reachable. Wire Arena:"
  echo "  open /arena?workers=$(echo "${URLS[0]}" | sed 's#^https\?://##')"
  echo "  export NEXT_PUBLIC_AKASH_WORKER_URLS='${URLS[*]// /,}'"
  exit 0
fi

echo "Some required checks failed. Inspect logs above or re-run with --json"
exit 1

#!/usr/bin/env bash
# Monitor Akash lease health and service status.
#
# Usage:
#   ./deploy/akash/monitor-lease.sh
#   ./deploy/akash/monitor-lease.sh --wait --dseq 12345 --provider akash1...
#   ./deploy/akash/monitor-lease.sh --watch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_FILE="${REPO_ROOT}/deploy/.akash-deployment.json"
PS="${PROVIDER_SERVICES_BIN:-provider-services}"
WATCH=false
WAIT=false
DSEQ=""
PROVIDER=""
MAX_WAIT=180

export PATH="${REPO_ROOT}/bin:${PATH}"
[[ -x "${REPO_ROOT}/bin/provider-services" ]] && PS="${REPO_ROOT}/bin/provider-services"

log() { printf '[monitor] %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch) WATCH=true; shift ;;
    --wait) WAIT=true; shift ;;
    --dseq) DSEQ="$2"; shift 2 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --max-wait) MAX_WAIT="$2"; shift 2 ;;
    -h|--help) head -6 "$0"; exit 0 ;;
    *) log "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "${DSEQ}" || -z "${PROVIDER}" ]]; then
  if [[ -f "${STATE_FILE}" ]]; then
    DSEQ="$(jq -r '.dseq' "${STATE_FILE}")"
    PROVIDER="$(jq -r '.provider' "${STATE_FILE}")"
  else
    log "ERROR: no deployment state. Run deploy-full.sh first or pass --dseq/--provider"
    exit 1
  fi
fi

# shellcheck source=setup-auth.sh
source "${SCRIPT_DIR}/setup-auth.sh"
configure_akash_auth 2>/dev/null || true

if [[ -z "${AKASH_KEY_NAME:-}" ]]; then
  export AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm-admin}"
  export AKASH_KEYRING_BACKEND="${AKASH_KEYRING_BACKEND:-test}"
fi

check_once() {
  local ts
  ts="$(date -u +%H:%M:%S)"
  printf '\n── %s ──\n' "${ts}"
  printf 'dseq=%s provider=%s\n' "${DSEQ}" "${PROVIDER}"

  if lease_json="$("${PS}" lease-status \
      --dseq "${DSEQ}" \
      --provider "${PROVIDER}" \
      --from "${AKASH_KEY_NAME}" \
      --keyring-backend "${AKASH_KEYRING_BACKEND}" \
      -o json 2>/dev/null)"; then
    echo "${lease_json}" | jq '{
      state: .services[0].state,
      ready_replicas: .services[0].ready_replicas,
      total_replicas: .services[0].total_replicas,
      uris: .services[0].uris
    }' 2>/dev/null || echo "${lease_json}"
    URI="$(echo "${lease_json}" | jq -r '.services[0].uris[0] // empty')"
    if [[ -n "${URI}" ]]; then
      if curl -sf --max-time 10 "${URI}/health" -o /tmp/health.json 2>/dev/null; then
        log "Health OK: $(cat /tmp/health.json)"
        return 0
      elif curl -sf --max-time 10 "${URI}/" -o /dev/null 2>/dev/null; then
        log "HTTP OK at ${URI}/"
        return 0
      else
        log "WARN: URI reachable check failed: ${URI}"
        return 1
      fi
    fi
  else
    log "WARN: lease-status failed (lease may still be starting)"
    return 1
  fi
  return 1
}

if [[ "${WAIT}" == "true" ]]; then
  log "Waiting up to ${MAX_WAIT}s for lease to become healthy"
  elapsed=0
  while [[ "${elapsed}" -lt "${MAX_WAIT}" ]]; do
    if check_once; then
      log "Lease is healthy"
      exit 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  log "WARN: health check did not pass within ${MAX_WAIT}s"
  exit 1
fi

if [[ "${WATCH}" == "true" ]]; then
  while true; do
    check_once || true
    sleep 30
  done
fi

check_once

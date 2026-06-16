#!/usr/bin/env bash
# Obtain Tesla partner token, register domain, verify public key hosting.
#
# Usage:
#   export TESLA_CLIENT_ID=...
#   export TESLA_CLIENT_SECRET=...
#   export TESLA_DOMAIN=yieldswarm-agent-swarm-v2-51zx4tmk-support-6930s-projects.vercel.app
#   ./scripts/register-tesla-fleet.sh na
#   ./scripts/register-tesla-fleet.sh all    # na + eu (+ cn if TESLA_CN=1)
#
# Saves responses to .run/tesla-registration-<region>.json (gitignored)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"

# shellcheck source=scripts/lib/tesla-fleet.sh
source "${SCRIPT_DIR}/lib/tesla-fleet.sh"

log() { echo "[register-tesla-fleet] $*"; }
die() { log "ERROR: $*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required: $1"; }

register_region() {
  local region="$1"
  local domain="${TESLA_DOMAIN:?set TESLA_DOMAIN (no https:// prefix)}"
  local token_resp token

  log "region=${region} domain=${domain}"

  token_resp="$(tesla_partner_token "${region}")"
  token="$(printf '%s' "${token_resp}" | jq -r '.access_token // empty')"
  [[ -n "${token}" ]] || die "failed to obtain partner token for ${region}"

  mkdir -p "${RUN_DIR}"
  printf '%s' "${token_resp}" | jq '.' > "${RUN_DIR}/tesla-partner-token-${region}.json"
  chmod 600 "${RUN_DIR}/tesla-partner-token-${region}.json"

  local reg_resp verify_resp
  reg_resp="$(tesla_register_domain "${region}" "${token}" "${domain}")"
  printf '%s' "${reg_resp}" | jq '.' > "${RUN_DIR}/tesla-registration-${region}.json"

  verify_resp="$(tesla_verify_public_key "${region}" "${token}" "${domain}")"
  printf '%s' "${verify_resp}" | jq '.' > "${RUN_DIR}/tesla-public-key-verify-${region}.json"

  log "registered ${region} — saved ${RUN_DIR}/tesla-registration-${region}.json"
  log "public key verify: ${RUN_DIR}/tesla-public-key-verify-${region}.json"
}

main() {
  need_cmd curl
  need_cmd jq

  local target="${1:-na}"

  # Preflight: public key must be reachable
  local domain="${TESLA_DOMAIN:-}"
  [[ -n "${domain}" ]] || die "TESLA_DOMAIN unset"
  local pubkey_url="https://${domain}/.well-known/appspecific/com.tesla.3p.public-key.pem"
  log "checking public key URL: ${pubkey_url}"
  if ! curl -sfI "${pubkey_url}" | head -1 | grep -qE '200|301|302'; then
    log "WARN: public key not yet reachable at ${pubkey_url}"
    log "      Deploy Vercel first, then re-run. Continuing anyway..."
  else
    log "OK public key reachable"
  fi

  case "${target}" in
    all)
      register_region na
      register_region eu
      if [[ "${TESLA_CN:-0}" == "1" ]]; then
        register_region cn
      fi
      ;;
    na|eu|cn) register_region "${target}" ;;
    *) die "usage: $0 [na|eu|cn|all]" ;;
  esac

  log "done — see docs/TESLA_FLEET_INTEGRATION.md for telemetry next steps"
}

main "$@"

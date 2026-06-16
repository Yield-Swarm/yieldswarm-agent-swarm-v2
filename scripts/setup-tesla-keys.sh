#!/usr/bin/env bash
# Generate Tesla Fleet API EC key pair (prime256v1) and install public key for hosting.
#
# Usage:
#   ./scripts/setup-tesla-keys.sh              # generate new keys
#   ./scripts/setup-tesla-keys.sh --rotate     # backup old + generate new
#   ./scripts/setup-tesla-keys.sh --check      # verify public key file exists
#
# Output:
#   tesla/keys/private-key.pem          (gitignored — NEVER commit)
#   public/.well-known/appspecific/com.tesla.3p.public-key.pem  (deploy to Vercel)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

KEY_DIR="${TESLA_KEY_DIR:-${REPO_ROOT}/tesla/keys}"
PRIVATE_KEY="${TESLA_PRIVATE_KEY_PATH:-${KEY_DIR}/private-key.pem}"
PUBLIC_HOST_PATH="${REPO_ROOT}/public/.well-known/appspecific/com.tesla.3p.public-key.pem"
PUBLIC_COPY="${KEY_DIR}/com.tesla.3p.public-key.pem"

log() { echo "[setup-tesla-keys] $*"; }
die() { log "ERROR: $*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required: $1"; }

cmd_check() {
  if [[ -f "${PUBLIC_HOST_PATH}" ]]; then
    log "OK public key hosted at: ${PUBLIC_HOST_PATH}"
    openssl ec -pubin -in "${PUBLIC_HOST_PATH}" -text -noout 2>/dev/null | head -3 || true
    exit 0
  fi
  die "public key missing — run without --check to generate"
}

cmd_rotate() {
  if [[ -f "${PRIVATE_KEY}" ]]; then
    local backup="${PRIVATE_KEY}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    cp "${PRIVATE_KEY}" "${backup}"
    chmod 600 "${backup}"
    log "backed up private key to ${backup}"
  fi
}

main() {
  local rotate=0 check=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --rotate) rotate=1; shift ;;
      --check)  check=1; shift ;;
      -h|--help)
        sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *) die "unknown arg: $1" ;;
    esac
  done

  [[ "${check}" -eq 1 ]] && cmd_check
  [[ "${rotate}" -eq 1 ]] && cmd_rotate

  need_cmd openssl

  mkdir -p "${KEY_DIR}" "$(dirname "${PUBLIC_HOST_PATH}")"
  chmod 700 "${KEY_DIR}"

  if [[ -f "${PRIVATE_KEY}" && "${rotate}" -eq 0 ]]; then
    log "private key already exists at ${PRIVATE_KEY} (use --rotate to replace)"
  else
    log "generating EC key pair (prime256v1 / secp256r1)"
    openssl ecparam -name prime256v1 -genkey -noout -out "${PRIVATE_KEY}"
    chmod 600 "${PRIVATE_KEY}"
  fi

  openssl ec -in "${PRIVATE_KEY}" -pubout -out "${PUBLIC_COPY}"
  chmod 644 "${PUBLIC_COPY}"
  cp "${PUBLIC_COPY}" "${PUBLIC_HOST_PATH}"
  chmod 644 "${PUBLIC_HOST_PATH}"

  log "private key: ${PRIVATE_KEY} (gitignored)"
  log "public key:  ${PUBLIC_HOST_PATH}"
  log ""
  log "Next steps:"
  log "  1. Deploy to Vercel so this URL is live:"
  log "     https://<your-vercel-domain>/.well-known/appspecific/com.tesla.3p.public-key.pem"
  log "  2. Register domain (must match developer.tesla.com allowed_origins):"
  log "     export TESLA_CLIENT_ID=... TESLA_CLIENT_SECRET=... TESLA_DOMAIN=<root-domain>"
  log "     ./scripts/register-tesla-fleet.sh na"
  log ""
  log "See docs/TESLA_FLEET_INTEGRATION.md"
}

main "$@"

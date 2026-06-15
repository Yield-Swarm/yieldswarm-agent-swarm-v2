#!/usr/bin/env bash
# Ensure a valid JWT exists, or fall back to keyring auth.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib/jwt-utils.sh"

# Load env without banner
ROOT="$(cd "${HERE}/.." && pwd)"
if [[ -f "${ROOT}/deploy/config.env" ]]; then
  # shellcheck disable=SC1091
  set -a && source "${ROOT}/deploy/config.env" && set +a
fi
export PATH="${PATH}:${HOME}/bin:/root/bin}"
export AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm}"
export AKASH_KEYRING_BACKEND="${AKASH_KEYRING_BACKEND:-test}"
if [[ -f "${ROOT}/.run/akash-jwt.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/.run/akash-jwt.env"
fi
akash_jwt_export 2>/dev/null || true

use_keyring() {
  unset AKASH_JWT 2>/dev/null || true
  export AKASH_AUTH_METHOD=keyring
  echo "akash-jwt-ensure: keyring fallback (AKASH_KEY_NAME=${AKASH_KEY_NAME})" >&2
}

# Explicit keyring mode — skip JWT entirely.
if [[ "${AKASH_AUTH_METHOD:-keyring}" == "keyring" && "${1:-}" != "--refresh" ]]; then
  use_keyring
  exit 0
fi

STATUS="$(akash_jwt_status)"

if [[ "${STATUS}" == "valid" ]]; then
  export AKASH_AUTH_METHOD=jwt
  echo "akash-jwt-ensure: JWT valid" >&2
  exit 0
fi

if [[ "${STATUS}" == "stale" ]]; then
  export AKASH_AUTH_METHOD=jwt
  echo "akash-jwt-ensure: JWT stale (refresh soon); still usable" >&2
  exit 0
fi

# expired | missing | malformed — attempt refresh
echo "akash-jwt-ensure: JWT ${STATUS} — regenerating..." >&2
if bash "${HERE}/akash-generate-jwt.sh" >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "${ROOT}/.run/akash-jwt.env"
  akash_jwt_export
  export AKASH_AUTH_METHOD=jwt
  echo "akash-jwt-ensure: JWT refreshed" >&2
  exit 0
fi

echo "akash-jwt-ensure: refresh failed — keyring fallback" >&2
use_keyring

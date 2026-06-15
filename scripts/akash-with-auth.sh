#!/usr/bin/env bash
# Run a command with Akash auth resolved (JWT if valid, else keyring).
# Usage: bash scripts/akash-with-auth.sh [--jwt-only|--keyring-only] <command> [args...]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="auto"

if [[ "${1:-}" == "--jwt-only" ]]; then
  MODE="jwt"
  shift
elif [[ "${1:-}" == "--keyring-only" ]]; then
  MODE="keyring"
  shift
fi

[[ $# -gt 0 ]] || { echo "usage: akash-with-auth.sh [--jwt-only|--keyring-only] <cmd> [args...]" >&2; exit 1; }

# shellcheck disable=SC1091
source "${HERE}/akash-env.sh" >/dev/null 2>&1

if [[ "${MODE}" == "keyring" ]]; then
  export AKASH_AUTH_METHOD=keyring
  unset AKASH_JWT 2>/dev/null || true
elif [[ "${MODE}" == "jwt" ]]; then
  bash "${HERE}/akash-jwt-ensure.sh" --refresh
  # shellcheck disable=SC1091
  source "${HERE}/../.run/akash-jwt.env" 2>/dev/null || true
  # shellcheck disable=SC1091
  source "${HERE}/lib/jwt-utils.sh"
  akash_jwt_export
  [[ "$(akash_jwt_status)" == "valid" || "$(akash_jwt_status)" == "stale" ]] || {
    echo "ERROR: --jwt-only but no valid JWT" >&2
    exit 1
  }
else
  bash "${HERE}/akash-jwt-ensure.sh"
  # shellcheck disable=SC1091
  source "${HERE}/../.run/akash-jwt.env" 2>/dev/null || true
fi

exec "$@"

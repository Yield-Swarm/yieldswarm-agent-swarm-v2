#!/usr/bin/env bash
# Show Akash JWT status (never prints the full token).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/akash-env.sh" >/dev/null 2>&1 || true
# shellcheck disable=SC1091
source "${HERE}/lib/jwt-utils.sh"

STATUS="$(akash_jwt_status)"
EXP="$(akash_jwt_exp 2>/dev/null || echo "")"
NOW="$(date +%s)"

echo "Akash JWT status: ${STATUS}"
echo "  AKASH_AUTH_METHOD=${AKASH_AUTH_METHOD:-keyring}"
echo "  AKASH_JWT_FILE=${AKASH_JWT_FILE:-<unset>}"

if [[ -n "${EXP}" && "${EXP}" != "0" ]]; then
  REMAINING=$((EXP - NOW))
  echo "  expires_at=$(date -u -d "@${EXP}" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || date -u -r "${EXP}" '+%Y-%m-%d %H:%M:%S UTC')"
  if (( REMAINING > 0 )); then
    echo "  remaining=${REMAINING}s (~$((REMAINING / 60)) min)"
  else
    echo "  remaining=0 (expired)"
  fi
fi

case "${STATUS}" in
  valid)   echo "  action=ready" ;;
  stale)   echo "  action=refresh soon (within ${AKASH_JWT_REFRESH_BUFFER_SECONDS:-300}s buffer)" ;;
  expired) echo "  action=run: bash scripts/akash-generate-jwt.sh" ;;
  missing) echo "  action=generate JWT or use keyring fallback (AKASH_AUTH_METHOD=keyring)" ;;
  *)       echo "  action=regenerate token" ;;
esac

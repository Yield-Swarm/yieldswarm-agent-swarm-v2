#!/usr/bin/env bash
# Secure export pattern — loads JWT into env without echoing the token.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
ENV_FILE="${ROOT}/.run/akash-jwt.env"
JWT_FILE="${ROOT}/.run/akash-jwt.txt"

# shellcheck disable=SC1091
source "${HERE}/lib/jwt-utils.sh"

if [[ ! -r "${JWT_FILE}" && ! -r "${ENV_FILE}" ]]; then
  echo "No JWT found. Generate first:" >&2
  echo "  bash scripts/akash-generate-jwt.sh" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"
akash_jwt_export

STATUS="$(akash_jwt_status)"
if [[ "${STATUS}" == "expired" || "${STATUS}" == "malformed" ]]; then
  echo "JWT is ${STATUS}. Regenerate:" >&2
  echo "  bash scripts/akash-generate-jwt.sh" >&2
  exit 1
fi

export AKASH_AUTH_METHOD=jwt
echo "JWT exported (auth=jwt, status=${STATUS})"
echo "  AKASH_JWT_FILE=${AKASH_JWT_FILE}"
echo "  token_prefix=${AKASH_JWT:0:12}..."

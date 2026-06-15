#!/usr/bin/env bash
# Generate a short-lived Akash JWT using YOUR local key (never share the key).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
# shellcheck disable=SC1091
source "${HERE}/akash-env.sh" >/dev/null 2>&1
# shellcheck disable=SC1091
source "${HERE}/lib/jwt-utils.sh"

command -v provider-services >/dev/null 2>&1 || {
  echo "ERROR: provider-services not installed" >&2
  echo "See: https://akash.network/docs/developers/deployment/cli/installation-guide/" >&2
  exit 1
}

JWT_FILE="${ROOT}/.run/akash-jwt.txt"
ENV_FILE="${ROOT}/.run/akash-jwt.env"
META_FILE="${ROOT}/.run/akash-jwt.meta.json"

echo "Generating JWT (signed with key '${AKASH_KEY_NAME}' — confirms on-chain)..."
OUT="$(mktemp)"
trap 'rm -f "${OUT}"' EXIT

if ! provider-services tx auth generate-jwt --help >/dev/null 2>&1; then
  echo "ERROR: tx auth generate-jwt not available in this provider-services build" >&2
  echo "Use keyring fallback: export AKASH_AUTH_METHOD=keyring" >&2
  exit 1
fi

provider-services tx auth generate-jwt \
  --from "${AKASH_KEY_NAME}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --node "${AKASH_NODE}" \
  --keyring-backend "${AKASH_KEYRING_BACKEND}" \
  --gas "${AKASH_GAS}" \
  --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
  --yes \
  --output json > "${OUT}" 2>&1 || {
    cat "${OUT}" >&2
    exit 1
  }

TOKEN="$(jq -r '.token // .jwt // .data.token // empty' "${OUT}" 2>/dev/null || true)"
if [[ -z "${TOKEN}" ]]; then
  TOKEN="$(grep -oE 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' "${OUT}" | head -1 || true)"
fi
[[ -n "${TOKEN}" ]] || { echo "ERROR: could not parse JWT from CLI output" >&2; cat "${OUT}" >&2; exit 1; }

akash_jwt_secure_write "${TOKEN}" "${JWT_FILE}" "${ENV_FILE}" "${META_FILE}"

echo ""
echo "JWT stored securely in .run/ (gitignored, mode 600)"
echo "  bash scripts/akash-jwt-status.sh     # check expiry"
echo "  source scripts/akash-jwt-export.sh   # load into session"
echo "  token_prefix=${TOKEN:0:16}..."

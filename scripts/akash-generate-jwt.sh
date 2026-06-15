#!/usr/bin/env bash
# Generate a short-lived Akash JWT using YOUR local key (never share the key).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/akash-env.sh"

command -v provider-services >/dev/null 2>&1 || {
  echo "ERROR: provider-services not installed" >&2
  echo "See: https://akash.network/docs/developers/deployment/cli/installation-guide/" >&2
  exit 1
}

mkdir -p "${HERE}/../.run"

echo "Generating JWT (signed with key '${AKASH_KEY_NAME}' — you will confirm the tx)..."
OUT="$(mktemp)"
trap 'rm -f "${OUT}"' EXIT

# Akash mainnet 14+ / provider-services v0.10+
if provider-services tx auth generate-jwt --help >/dev/null 2>&1; then
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
    # Some builds print the raw JWT to stdout
    TOKEN="$(grep -oE 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' "${OUT}" | head -1 || true)"
  fi
else
  echo "WARN: tx auth generate-jwt not available — provider-services auto-signs JWT when using --from" >&2
  echo "For CI, upgrade provider-services or use keyring auth (AKASH_AUTH_METHOD=keyring)" >&2
  exit 1
fi

[[ -n "${TOKEN}" ]] || { echo "ERROR: could not parse JWT from CLI output" >&2; cat "${OUT}" >&2; exit 1; }

JWT_FILE="${HERE}/../.run/akash-jwt.txt"
echo "${TOKEN}" > "${JWT_FILE}"
cat > "${HERE}/../.run/akash-jwt.env" <<EOF
export AKASH_JWT="${TOKEN}"
export AKASH_JWT_FILE="${JWT_FILE}"
export AKASH_AUTH_METHOD=jwt
EOF

echo ""
echo "JWT generated (short-lived — regenerate every few hours)."
echo "  export AKASH_JWT=\"\$(cat ${JWT_FILE})\""
echo "  source ${HERE}/../.run/akash-jwt.env"
echo ""
echo "Token prefix: ${TOKEN:0:20}..."

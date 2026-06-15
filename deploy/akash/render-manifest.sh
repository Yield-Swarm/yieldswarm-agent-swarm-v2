#!/usr/bin/env bash
set -euo pipefail

for required_bin in envsubst; do
  if ! command -v "${required_bin}" >/dev/null 2>&1; then
    echo "Missing dependency: ${required_bin}" >&2
    exit 1
  fi
done

: "${IMAGE_TAG:?Set IMAGE_TAG}"
: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID}"
: "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
envsubst < "${SCRIPT_DIR}/deployment.yaml" > "${SCRIPT_DIR}/deployment.rendered.yaml"

echo "Rendered ${SCRIPT_DIR}/deployment.rendered.yaml"

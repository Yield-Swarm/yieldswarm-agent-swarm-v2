#!/usr/bin/env bash
# Teardown burst resources for a provider.
# Usage: PROVIDER=vast ./scripts/multicloud/teardown-worker.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDER="${PROVIDER:?set PROVIDER}"

PROVIDER_SCRIPT="${SCRIPT_DIR}/providers/${PROVIDER}.sh"
[[ -x "${PROVIDER_SCRIPT}" ]] || { echo "provider script missing: ${PROVIDER_SCRIPT}"; exit 1; }

exec "${PROVIDER_SCRIPT}" teardown

#!/usr/bin/env bash
# Canonical production Akash deploy: Vault wrap → monolith SDL → auto-heal
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"

export SDL_FILE="${SDL_FILE:-deploy/deploy-swarm-monolith.yaml}"
export AUTO_HEAL="${AUTO_HEAL:-1}"
export AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"

bash "${ROOT}/scripts/akash-deploy-with-vault.sh" "${SDL_FILE}"

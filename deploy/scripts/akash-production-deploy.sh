#!/usr/bin/env bash
# Canonical production Akash mainnet deploy — Vault Agent + optional Cherry preflight.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
export SDL_FILE="${SDL_FILE:-deploy/deploy-swarm-monolith.yaml}"
exec bash "${ROOT}/scripts/akash-mainnet-production.sh" "$@"

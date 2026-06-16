#!/usr/bin/env bash
# Deploy a named Akash SDL tier (backend | bittensor | odysseus | monolith).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"

TIER="${1:-}"
shift || true

case "${TIER}" in
  backend|a)
    SDL="${ROOT}/deploy/akash-backend.sdl.yml"
    ;;
  bittensor|b|miner)
    SDL="${ROOT}/deploy/akash-bittensor-miner.sdl.yml"
    ;;
  odysseus|c|full)
    SDL="${ROOT}/deploy/akash-odysseus.sdl.yml"
    ;;
  monolith|m)
    SDL="${ROOT}/deploy/deploy-swarm-monolith.yaml"
    ;;
  "")
    echo "Usage: $0 <backend|bittensor|odysseus|monolith> [extra akash-deploy args...]" >&2
    echo "See docs/AKASH_SDL_BUDGETS.md" >&2
    exit 1
    ;;
  *)
    echo "Unknown tier: ${TIER}" >&2
    exit 1
    ;;
esac

export AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"
exec "${HERE}/akash-deploy.sh" "${SDL}" "$@"

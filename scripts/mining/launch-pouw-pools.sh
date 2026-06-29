#!/usr/bin/env bash
# Launch all six PoWUoI mining pools (PRL, KRX, ZANO, QTC, IRON, TON) on YieldSwarm.
#
# Usage:
#   ./scripts/mining/launch-pouw-pools.sh              # dry-run configs + local supervisors
#   ./scripts/mining/launch-pouw-pools.sh --live       # MINING_DRY_RUN=0
#   ./scripts/mining/launch-pouw-pools.sh --akash      # also deploy Akash SDLs (needs Vault + funded wallet)
#   ./scripts/mining/launch-pouw-pools.sh status
#   ./scripts/mining/launch-pouw-pools.sh render-sdl
#
# PRL is the YieldSwarm-native coin (MINING_ROOT_PRL / treasury manifest).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"

CMD="${1:-launch}"
shift || true

DEPLOY_AKASH=false
LIVE=false
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --akash) DEPLOY_AKASH=true; shift ;;
    --live) LIVE=true; shift ;;
    --json) EXTRA+=(--json); shift ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "${LIVE}" == "true" ]]; then
  export MINING_DRY_RUN=0
fi

# Default: all six PoWUoI coins enabled unless overridden in env
export POUW_PRL_ENABLED="${POUW_PRL_ENABLED:-true}"
export POUW_KRX_ENABLED="${POUW_KRX_ENABLED:-true}"
export POUW_ZANO_ENABLED="${POUW_ZANO_ENABLED:-true}"
export POUW_QTC_ENABLED="${POUW_QTC_ENABLED:-true}"
export POUW_IRON_ENABLED="${POUW_IRON_ENABLED:-true}"
export POUW_TON_ENABLED="${POUW_TON_ENABLED:-true}"

AKASH_FLAG=()
if [[ "${DEPLOY_AKASH}" == "true" ]]; then
  AKASH_FLAG=(--deploy-akash)
  if [[ -z "${VAULT_ADDR:-}" || -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ]]; then
    echo "[pouw] ERROR: --akash requires VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID" >&2
    exit 1
  fi
fi

case "${CMD}" in
  launch)
    exec python3 -m mining.pouw_launcher launch "${AKASH_FLAG[@]}" "${EXTRA[@]}"
    ;;
  status|render-sdl|state)
    exec python3 -m mining.pouw_launcher "${CMD}" "${EXTRA[@]}"
    ;;
  *)
    echo "Usage: $0 [launch|status|render-sdl|state] [--live] [--akash] [--json]" >&2
    exit 1
    ;;
esac

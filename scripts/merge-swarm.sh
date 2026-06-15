#!/usr/bin/env bash
# YieldSwarm merge coordinator — post-consolidation mode.
#
# main already contains the integrated monorepo. This script:
#   - analyzes remaining cursor/* branches
#   - optionally syncs environment branches to main
#   - optionally initializes missing environment branches
#
# Usage:
#   ./scripts/merge-swarm.sh                    # analyze + report
#   ./scripts/merge-swarm.sh --sync-env         # sync env branches to main
#   ./scripts/merge-swarm.sh --init-branches-only
#   ./scripts/merge-swarm.sh --dry-run
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SYNC_ENV=false
INIT_ONLY=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --sync-env) SYNC_ENV=true ;;
    --init-branches-only) INIT_ONLY=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
  esac
done

echo "==> YieldSwarm merge coordinator (post-consolidation)"
git fetch origin --prune

MAIN_SHORT="$(git rev-parse --short main)"
echo "main tip: $MAIN_SHORT"

if $INIT_ONLY || $SYNC_ENV; then
  ARGS=()
  $DRY_RUN && ARGS+=(--dry-run)
  $INIT_ONLY && ARGS+=(--init)
  exec "$REPO_ROOT/scripts/sync-environment-branches.sh" "${ARGS[@]}"
fi

echo ""
"$REPO_ROOT/scripts/analyze-cursor-branches.sh"

echo ""
echo "==> Pending merges (manual — open PRs to development first)"
echo "  1. origin/cursor/odysseus-brain-e512      → development → main"
echo "  2. origin/cursor/mega-round-integration-e512 → development → main"
echo ""
echo "==> Optional review branch"
echo "  origin/cursor/helix-chain-activation-597f → development only (144 files, vault overlap)"
echo ""
echo "To sync environment branches after main is updated:"
echo "  ./scripts/merge-swarm.sh --sync-env"
echo ""
echo "Legacy one-shot integration (pre-consolidation) is no longer needed."
echo "See MERGE_STRATEGY.md for the full safe merge plan."

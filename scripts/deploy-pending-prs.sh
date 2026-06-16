#!/usr/bin/env bash
# Safe integration-branch deploy for pending PRs.
# Does NOT bulk-merge stale/conflicting branches — see docs/PR_CLOSE_CHECKLIST.md
#
# Usage:
#   bash scripts/deploy-pending-prs.sh                    # integration/$(date +%Y-%m-%d)
#   bash scripts/deploy-pending-prs.sh integration/2026-06-16
#   bash scripts/deploy-pending-prs.sh --to-main            # merge integration → main after tests
#   bash scripts/deploy-pending-prs.sh --dry-run
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

INTEGRATION_BRANCH="${1:-integration/$(date +%Y-%m-%d)}"
TO_MAIN=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --to-main) TO_MAIN=true ;;
    --dry-run) DRY_RUN=true ;;
    integration/*) INTEGRATION_BRANCH="$arg" ;;
  esac
done

# Mergeable agent PRs + pillar branches (skip if already ancestor of main)
MERGE_CANDIDATES=(
  origin/cursor/mandelbrot-neon-logging-4f85
  origin/cursor/pr-review-handoff-4f85
)

# Never bulk-merge — selective port only (see docs/ARENA_TELEMETRY_MERGE_PLAN.md)
SKIP_BRANCHES=(
  origin/cursor/arena-telemetry-dashboard-c904      # PR #4 — stale, selective port
  origin/cursor/arena-akash-telemetry-f187          # PR #9 — stale, selective port
  origin/cursor/multicloud-fallback-6923            # PR #8 — extract modules only
  origin/cursor/greatdelta-emission-router-1068     # PR #10 — superseded
  origin/cursor/zk-entropy-proof-597f               # PR #43 — superseded
  origin/cursor/god-prompt-helical-build-d1cd       # PR #41 — defer
)

run() {
  if $DRY_RUN; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

echo "==> Fetch all"
run git fetch --all

echo "==> Base: main @ $(git rev-parse --short origin/main)"
run git checkout main
run git pull origin main
run git checkout -B "$INTEGRATION_BRANCH" origin/main

merged=0
skipped=0

for branch in "${MERGE_CANDIDATES[@]}"; do
  name="${branch#origin/}"
  if git merge-base --is-ancestor "$branch" HEAD 2>/dev/null; then
    echo "  skip $name (already in integration/main)"
    skipped=$((skipped + 1))
    continue
  fi
  echo "==> merge $branch"
  if $DRY_RUN; then
    echo "    [dry-run] would merge $branch"
    merged=$((merged + 1))
    continue
  fi
  if git merge "$branch" -m "Merge $name into $INTEGRATION_BRANCH"; then
    merged=$((merged + 1))
  else
    echo "CONFLICT on $branch — resolve manually" >&2
    exit 1
  fi
done

echo ""
echo "Skipped stale/superseded branches (do not auto-merge):"
for b in "${SKIP_BRANCHES[@]}"; do echo "  - $b"; done

echo ""
echo "==> Tests"
if ! $DRY_RUN; then
  npm run test:unit
  (cd backend && npm test)
fi

run git push -u origin "$INTEGRATION_BRANCH"

if $TO_MAIN && ! $DRY_RUN; then
  echo "==> Promote $INTEGRATION_BRANCH → main"
  git checkout main
  git pull origin main
  git merge "$INTEGRATION_BRANCH" -m "Merge $INTEGRATION_BRANCH to main"
  git push origin main
  bash scripts/sync-environment-branches.sh
  echo "==> Close superseded: bash scripts/close-superseded-prs.sh"
fi

echo ""
echo "Done. merged=$merged skipped=$skipped branch=$INTEGRATION_BRANCH tip=$(git rev-parse --short HEAD 2>/dev/null || echo n/a)"

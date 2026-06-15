#!/usr/bin/env bash
# YieldSwarm canonical merge script — run from a clean checkout of main.
set -euo pipefail

INTEGRATION_BRANCH="${INTEGRATION_BRANCH:-cursor/merge-coordination-93dd}"

echo "==> Fetching all branches..."
git fetch --all --prune

echo "==> Fast-path: merge integration branch $INTEGRATION_BRANCH"
git checkout main
git merge --no-ff "origin/$INTEGRATION_BRANCH" -m "Merge swarm integration from $INTEGRATION_BRANCH"

echo "==> Creating environment branches..."
for env in development testnet devnets production MAINNET; do
  if git show-ref --verify --quiet "refs/heads/$env"; then
    echo "  branch $env already exists — skipping"
  else
    git branch "$env" main
    echo "  created $env"
  fi
done

echo ""
echo "Done. Push with:"
echo "  git push -u origin main development testnet devnets production MAINNET"

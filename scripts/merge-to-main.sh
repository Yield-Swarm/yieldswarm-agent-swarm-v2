#!/usr/bin/env bash
# Merge development integration branch into main and create environment branches.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Fetching latest from origin"
git fetch origin

echo "==> Ensuring clean working tree"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: uncommitted changes. Commit or stash first." >&2
  exit 1
fi

echo "==> Merging origin/development into main"
git checkout main
git pull origin main || true
git merge origin/development --no-edit -m "Merge development: consolidated cursor/* integration"

ENV_BRANCHES=(development testnet devnets production MAINNET)
for branch in "${ENV_BRANCHES[@]}"; do
  echo "==> Syncing branch: $branch"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git checkout "$branch"
    git merge main --no-edit -m "Sync $branch with main"
  else
    git checkout -b "$branch" main
  fi
  git push -u origin "$branch" || git push origin "$branch"
done

git checkout main
git push -u origin main

echo "==> Done. Branches synced: main + ${ENV_BRANCHES[*]}"

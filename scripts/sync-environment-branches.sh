#!/usr/bin/env bash
# Fast-forward environment branches (development, testnet, devnets, production, MAINNET) to main.
#
# Usage:
#   ./scripts/sync-environment-branches.sh           # sync all env branches to main
#   ./scripts/sync-environment-branches.sh --dry-run
#   ./scripts/sync-environment-branches.sh --init  # create missing branches from main
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=false
INIT_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --init) INIT_ONLY=true ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
  esac
done

ENV_BRANCHES=(development testnet devnets production MAINNET)

echo "==> Fetching origin..."
git fetch origin --prune

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: uncommitted changes. Commit or stash first." >&2
  exit 1
fi

MAIN="$(git rev-parse main)"
MAIN_SHORT="$(git rev-parse --short "$MAIN")"
echo "main tip: $MAIN_SHORT"

git checkout main
git pull origin main 2>/dev/null || true

sync_branch() {
  local branch="$1"
  local remote_ref="refs/remotes/origin/$branch"

  if ! git show-ref --verify --quiet "$remote_ref"; then
    echo "  $branch: missing on origin — creating from main"
    if $DRY_RUN; then
      echo "    [dry-run] would create $branch from $MAIN_SHORT"
      return
    fi
    git branch -f "$branch" "$MAIN"
    git push -u origin "$branch"
    return
  fi

  local tip="$(git rev-parse "origin/$branch")"
  local behind="$(git rev-list --count "$tip..$MAIN")"
  local ahead="$(git rev-list --count "$MAIN..$tip")"

  if [[ "$tip" == "$MAIN" ]]; then
    echo "  $branch: already at $MAIN_SHORT"
    return
  fi

  if [[ "$ahead" -gt 0 ]]; then
    echo "  $branch: SKIP — $ahead commits ahead of main (manual merge required)" >&2
    return
  fi

  if [[ "$behind" -eq 0 ]]; then
    echo "  $branch: up to date"
    return
  fi

  echo "  $branch: fast-forward $behind commits → $MAIN_SHORT"
  if $DRY_RUN; then
    echo "    [dry-run] would reset $branch to $MAIN_SHORT"
    return
  fi

  git branch -f "$branch" "$MAIN"
  git push --force-with-lease origin "$branch"
}

echo "==> Syncing environment branches..."
for branch in "${ENV_BRANCHES[@]}"; do
  sync_branch "$branch"
done

git checkout main

if $DRY_RUN; then
  echo "==> Dry run complete. Re-run without --dry-run to apply."
else
  echo "==> Done. All environment branches aligned to main ($MAIN_SHORT)."
fi

#!/usr/bin/env bash
# git-sync-workspace.sh — Pull latest + show branch status on shared pod workspace
set -euo pipefail

REPO="${1:-${CODE_SERVER_WORKSPACE:-/workspace/yieldswarm-agent-swarm-v2}}"
BRANCH="${2:-}"

cd "${REPO}"
git fetch origin --prune
if [[ -n "${BRANCH}" ]]; then
  git checkout "${BRANCH}"
  git pull origin "${BRANCH}" || true
else
  git status -sb
fi
echo "---"
echo "Remote branches (cursor/*):"
git branch -r | grep 'origin/cursor/' | tail -10 || true

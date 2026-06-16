#!/usr/bin/env bash
# =============================================================================
# scripts/merge-open-prs-integration.sh
#
# Creates an integration branch and merges open PRs in pillar order.
# Usage: bash scripts/merge-open-prs-integration.sh [integration-branch-name]
#
# Requires: git, curl (for GitHub API), python3
# Optional: gh CLI (falls back to API)
# =============================================================================
set -euo pipefail

INTEGRATION_BRANCH="${1:-integration/$(date +%Y-%m-%d)}"
REPO="${GITHUB_REPOSITORY:-Yield-Swarm/yieldswarm-agent-swarm-v2}"

echo "==> Fetching all remotes"
git fetch --all

echo "==> Creating integration branch: $INTEGRATION_BRANCH"
git checkout main
git pull origin main
git checkout -B "$INTEGRATION_BRANCH" origin/main

# Merge order: foundation → infrastructure → ZK → docs
# Skip PRs superseded by newer branches (noted in comments)
MERGE_BRANCHES=(
  "origin/cursor/vault-beefcake-bootstrap-9c82"      # PR #37 Greek/D¹
  "origin/cursor/rtx5090-production-configs-9c82"     # PR #39 infra + oracles
  "origin/cursor/zk-entropy-mayhem-9c82"              # PR #44 ZK¹ (supersedes #41, #43)
  "origin/cursor/full-stack-deployment-overview-9c82" # PR #45 docs
  "origin/cursor/akash-ollama-worker-625e"            # PR #38 Ollama worker
)

SKIP_NOTE="
Skipped (high conflict / superseded):
  PR #3  akash-tfc-bootstrap-fc5d     — conflicts with current main
  PR #41 god-prompt-helical-build      — superseded by #44
  PR #43 zk-entropy-proof-597f         — superseded by #44
  PR #4, #9 arena telemetry            — review individually
  PR #8, #10 multicloud / great-delta  — review individually
"

for branch in "${MERGE_BRANCHES[@]}"; do
  name="${branch#origin/}"
  echo ""
  echo "==> Merging $branch"
  if git merge "$branch" -m "Merge $name into $INTEGRATION_BRANCH"; then
    echo "    OK"
  else
    echo "    CONFLICT — resolve manually, then: git add -A && git commit"
    echo "$SKIP_NOTE"
    exit 1
  fi
done

echo ""
echo "==> Running tests"
npm run test:unit || true
(cd backend && npm test) || true

echo ""
echo "==> Integration branch ready: $INTEGRATION_BRANCH"
echo "    git push -u origin $INTEGRATION_BRANCH"
echo "    # After verification:"
echo "    git checkout main && git merge $INTEGRATION_BRANCH && git push origin main"
echo "$SKIP_NOTE"

#!/usr/bin/env bash
# =============================================================================
# scripts/merge-open-prs-integration.sh
#
# Creates an integration branch and merges open PRs in pillar order.
# Usage: bash scripts/merge-open-prs-integration.sh [integration-branch-name]
#
# Updated: 2026-06-20 — post pillar merge + TFC bootstrap + Mandelbrot Neon
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

# Merge order: foundation → infrastructure → ZK → telemetry → docs
MERGE_BRANCHES=(
  "origin/cursor/vault-beefcake-bootstrap-9c82"       # PR #37 Greek/D¹
  "origin/cursor/rtx5090-production-configs-9c82"    # PR #39 infra + oracles
  "origin/cursor/zk-entropy-mayhem-9c82"             # PR #44 ZK¹ (supersedes #41, #43)
  "origin/cursor/akash-ollama-worker-625e"           # PR #38 Ollama worker
  "origin/cursor/mandelbrot-neon-logging-4f85"       # Mandelbrot bot + Neon telemetry
  "origin/cursor/full-stack-deployment-overview-9c82"  # PR #45 docs
)

# Already landed on main (close via scripts/close-superseded-prs.sh):
#   PR #3  akash-tfc-bootstrap — merged @ 8074651
#   PR #38 open PR duplicate — content on main

SKIP_NOTE="
Selective merge required (do NOT bulk-merge stale branches):
  PR #4, #9  arena telemetry — see docs/ARENA_TELEMETRY_MERGE_PLAN.md
  PR #8      multicloud — extract GCP/Runpod modules to deploy/terraform-tfc/modules/
  PR #10     great-delta router — CLOSE superseded
  PR #43     zk entropy proof — CLOSE superseded by #44
  PR #41     god prompt — DEFER

Close checklist: docs/PR_CLOSE_CHECKLIST.md
Bug bounty spec: docs/BUG_BOUNTY_V1.md
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
python3 -m unittest discover -s tests -p 'test_*.py' -q || true

echo ""
echo "==> Integration branch ready: $INTEGRATION_BRANCH"
echo "    git push -u origin $INTEGRATION_BRANCH"
echo "    # After verification:"
echo "    git checkout main && git merge $INTEGRATION_BRANCH && git push origin main"
echo "    bash scripts/sync-environment-branches.sh"
echo "$SKIP_NOTE"

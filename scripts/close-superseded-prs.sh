#!/usr/bin/env bash
# Close PRs superseded by pillar merge on main (2026-06-16).
# Usage: bash scripts/close-superseded-prs.sh [--dry-run]
set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

close_pr() {
  local num="$1"
  local comment="$2"
  if $DRY_RUN; then
    echo "[dry-run] would close PR #$num"
    echo "  comment: $comment"
    return
  fi
  if gh pr close "$num" --comment "$comment" 2>/dev/null; then
    echo "closed PR #$num"
  else
    echo "skip PR #$num (already closed or not found)" >&2
  fi
}

# Already merged — close with link
close_pr 3 "Superseded: ethically merged to main @ 8074651. Modular TFC at deploy/terraform-tfc/ + docs/DEPLOYMENT_GUIDE.md."

# Merged via integration — close duplicate open PR
close_pr 38 "Superseded: Akash Ollama GPU worker landed on main (deploy/akash/ollama-worker.sdl.yml). PR branch integrated via pillar merge 2026-06-16."

# Contract + ZK already on main
close_pr 10 "Superseded: GreatDeltaEmissionRouter.sol + emission adapters already on main. See contracts/GreatDeltaEmissionRouter.sol and backend/src/adapters/emissionRouter.js."

close_pr 43 "Superseded by PR #44 ZK Entropy Mayhem Mode + MutationController. See docs/MAYHEM_14_PILLAR_ZK.md and src/infrastructure/zk-entropy-prover.js."

# Draft defer
close_pr 41 "Deferred: God Prompt helical stack overlaps AgentSwarm OS + Mayhem Mode. Reopen when helical layer review is scheduled."

echo "Done. Arena PRs #4/#9: use docs/ARENA_TELEMETRY_MERGE_PLAN.md — do not auto-close."

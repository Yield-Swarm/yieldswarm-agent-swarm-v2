#!/usr/bin/env bash
# Live rewards payout sweep — flips dry-run off and runs full pipeline.
#
# Usage:
#   export VAULT_TOKEN=...
#   HELIX_GO_LIVE=1 ./scripts/rewards/go-live-sweep.sh
#
# Safer plan-only preview:
#   ./scripts/production/go-live.sh --dry-run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

echo "WARNING: INITIALIZING LIVE PAYOUT SWEEP SEQUENCE"
echo "Network Target: Mainnet | Production: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

if [[ "${HELIX_GO_LIVE:-0}" != "1" ]]; then
  echo "ABORT: set HELIX_GO_LIVE=1 to execute live sweeps (safety gate)"
  echo "  HELIX_GO_LIVE=1 $0"
  exit 2
fi

export REWARDS_DRY_RUN=0
export IOT_HUB_DRY_RUN=0
export MARKETING_DRY_RUN=0

if [[ -z "${VAULT_TOKEN:-}" && -z "${VAULT_ROLE_ID:-}" ]]; then
  echo "CRITICAL ERROR: VAULT_TOKEN or VAULT_ROLE_ID must be set."
  exit 1
fi

echo "Vault context verified. Attaching to secret engines..."

"${SCRIPT_DIR}/sweep-rewards.sh" --full --reshard --assemble --sweep

echo "Live payout cycle committed to on-chain matrix (see .run/rewards-*.json)."

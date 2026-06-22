#!/usr/bin/env bash
# Rewards reshard → assemble → sweep to treasury wallets & mining roots.
#
# Usage:
#   ./scripts/rewards/sweep-rewards.sh --status
#   ./scripts/rewards/sweep-rewards.sh --reshard --assemble --sweep
#   ./scripts/rewards/sweep-rewards.sh --full
#   REWARDS_DRY_RUN=0 ./scripts/rewards/sweep-rewards.sh --full
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"
export REWARDS_DRY_RUN="${REWARDS_DRY_RUN:-1}"

DO_RESHARD=0
DO_ASSEMBLE=0
DO_SWEEP=0
DO_FULL=0
DO_STATUS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) DO_STATUS=1; shift ;;
    --reshard) DO_RESHARD=1; shift ;;
    --assemble) DO_ASSEMBLE=1; shift ;;
    --sweep) DO_SWEEP=1; shift ;;
    --full) DO_FULL=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ "$DO_STATUS" == 1 ]]; then
  python3 services/rewards/cli.py status
  exit 0
fi

if [[ "$DO_FULL" == 1 ]]; then
  echo "=== REWARDS FULL PIPELINE (dry_run=${REWARDS_DRY_RUN}) ==="
  python3 services/rewards/cli.py full
  exit 0
fi

if [[ "$DO_RESHARD" == 1 ]]; then
  echo "=== REWARDS RESHARD ==="
  python3 services/rewards/cli.py reshard
fi

if [[ "$DO_ASSEMBLE" == 1 ]]; then
  echo "=== REWARDS ASSEMBLE ==="
  python3 services/rewards/cli.py assemble
fi

if [[ "$DO_SWEEP" == 1 ]]; then
  echo "=== REWARDS SWEEP (dry_run=${REWARDS_DRY_RUN}) ==="
  python3 services/rewards/cli.py sweep
fi

if [[ "$DO_RESHARD$DO_ASSEMBLE$DO_SWEEP$DO_FULL$DO_STATUS" == "00000" ]]; then
  echo "Usage: $0 --status | --full | --reshard [--assemble] [--sweep]" >&2
  exit 1
fi

echo "✅ Rewards pipeline step(s) complete. State: .run/rewards-*.json"

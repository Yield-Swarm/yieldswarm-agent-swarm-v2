#!/usr/bin/env bash
# Unified mining manager CLI
# Usage:
#   ./scripts/mining/mining-manager.sh status
#   ./scripts/mining/mining-manager.sh start --miner bittensor
#   ./scripts/mining/mining-manager.sh stop
#   ./scripts/mining/mining-manager.sh config
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

export REPO_ROOT
export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"

exec python3 -m mining "$@"

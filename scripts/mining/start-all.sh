#!/usr/bin/env bash
# Start all configured miners (respects MINING_DRY_RUN)
set -euo pipefail
"$(dirname "$0")/mining-manager.sh" start --json

#!/usr/bin/env bash
# Stop all miners
set -euo pipefail
"$(dirname "$0")/mining-manager.sh" stop --json

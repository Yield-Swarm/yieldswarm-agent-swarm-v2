#!/usr/bin/env bash
# Mining fleet status
set -euo pipefail
"$(dirname "$0")/mining-manager.sh" status --json

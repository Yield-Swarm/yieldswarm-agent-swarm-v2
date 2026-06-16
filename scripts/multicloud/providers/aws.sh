#!/usr/bin/env bash
set -euo pipefail
if [[ "${DRY_RUN:-1}" == "1" ]]; then echo "[dry-run] AWS launch"; exit 0; fi
echo "AWS ECS planned"
exit 1

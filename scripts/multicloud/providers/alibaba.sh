#!/usr/bin/env bash
set -euo pipefail
if [[ "${DRY_RUN:-1}" == "1" ]]; then echo "[dry-run] Alibaba launch"; exit 0; fi
echo "Alibaba filler capacity planned"
exit 1

#!/usr/bin/env bash
# scripts/akash-deploy.sh — convenience wrapper for akash/akash-deploy.sh
#
# The canonical implementation lives in akash/akash-deploy.sh. This wrapper
# exists so operators can invoke deployment from the repo root or Codespaces
# without memorising subdirectory paths.
#
# Usage (same as akash/akash-deploy.sh):
#   ./scripts/akash-deploy.sh check
#   ./scripts/akash-deploy.sh deploy [sdl_file]
#   ./scripts/akash-deploy.sh list
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${ROOT}/akash/akash-deploy.sh" "$@"

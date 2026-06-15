#!/usr/bin/env bash
# docker/entrypoint.sh
# Symlinked/copied from akash/entrypoint.sh — identical runtime secret injection.
# See akash/entrypoint.sh for full documentation.
#
# This file exists so Docker and Akash deployments use the exact same
# entrypoint logic from the same source of truth.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AKASH_ENTRYPOINT="$(dirname "$SCRIPT_DIR")/akash/entrypoint.sh"

if [[ -f "$AKASH_ENTRYPOINT" ]]; then
  # shellcheck source=../akash/entrypoint.sh
  exec bash "$AKASH_ENTRYPOINT" "$@"
else
  # Fallback: run the full script inline if akash/ is not present
  # (this branch handles cases where the Dockerfile copies only docker/)
  exec bash /entrypoint.sh "$@"
fi

#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-3000}"

if [[ $# -gt 0 ]]; then
  exec "$@"
fi

exec python3 -m http.server "${PORT}" --bind 0.0.0.0

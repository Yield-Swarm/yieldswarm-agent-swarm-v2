#!/usr/bin/env bash
set -euo pipefail

PROVIDER="${1:-}"

if [[ -z "${PROVIDER}" ]]; then
  echo "Usage: $0 <akash|vercel|render>"
  exit 1
fi

case "${PROVIDER}" in
  akash)
    exec "$(dirname "$0")/providers/akash.sh"
    ;;
  vercel)
    exec "$(dirname "$0")/providers/vercel.sh"
    ;;
  render)
    exec "$(dirname "$0")/providers/render.sh"
    ;;
  *)
    echo "Unknown provider: ${PROVIDER}"
    exit 1
    ;;
esac

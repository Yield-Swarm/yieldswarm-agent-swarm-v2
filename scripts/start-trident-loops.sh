#!/usr/bin/env bash
# Start Pentagramal SovereignLoopManager (5 worker threads).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="${ROOT}/.run"
mkdir -p "$RUN"
PIDF="${RUN}/trident-loops.pid"
LOGF="${RUN}/trident-loops.log"

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "[trident-loops] already running pid $(cat "$PIDF")"
  exit 0
fi

[[ -f "${ROOT}/deploy/env/trident-mainnet.env" ]] && set -a && source "${ROOT}/deploy/env/trident-mainnet.env" && set +a
[[ -f "${ROOT}/.env" ]] && set -a && source "${ROOT}/.env" && set +a

nohup npx tsx "${ROOT}/src/core/SovereignLoopManager.ts" >>"$LOGF" 2>&1 &
echo $! > "$PIDF"
echo "[trident-loops] started pid $(cat "$PIDF") log $LOGF"

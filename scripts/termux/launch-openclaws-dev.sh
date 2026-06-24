#!/usr/bin/env bash
# Termux / Android: launch Open Claws without production next build (no SWC binary).
# HP Windows / cloud: use scripts/windows/launch-hp-dashboard.ps1 or npm run dev.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export NEXT_DISABLE_SWC=1
export NEXT_PRIVATE_LOCAL_WEBPACK=true
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=2048}"
export PORT="${PORT:-3000}"

# shellcheck disable=SC1091
[[ -f deploy/env/trident-mainnet.env ]] && set -a && source deploy/env/trident-mainnet.env && set +a
[[ -f .env ]] && set -a && source .env && set +a

if [[ -f scripts/termux/detect-host.sh ]]; then
  KIND="$(bash scripts/termux/detect-host.sh)"
  if [[ "$KIND" == "termux-android" ]]; then
    echo "[termux] Raw Android detected — use proot for full build, or backend-only mode:"
    echo "  proot-distro login ubuntu -- bash -lc 'cd $ROOT && npm run dev'"
    echo "  npm run termux:backend   # integration API on :8080 (no Next.js)"
    if [[ "${TERMUX_BACKEND_ONLY:-1}" == "1" ]]; then
      exec npm run prod:backend
    fi
  fi
fi

rm -rf .next 2>/dev/null || true
if [[ ! -f .babelrc ]]; then
  echo '{ "presets": ["next/babel"] }' > .babelrc
fi

echo "[openclaws] Starting Next.js dev (no production build) on port $PORT"
exec npx next dev --port "$PORT"

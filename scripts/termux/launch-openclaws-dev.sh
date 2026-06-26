#!/usr/bin/env bash
# Termux / Android: Next.js dev without production build (no @next/swc-android-arm64).
# Prefer npm run termux:backend on raw Termux; use this inside proot Ubuntu.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export NEXT_DISABLE_SWC=1
export NEXT_PRIVATE_LOCAL_WEBPACK=true
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=2048}"
export PORT="${NEXT_PORT:-3000}"

[[ -f deploy/env/trident-mainnet.env ]] && set -a && source deploy/env/trident-mainnet.env && set +a
[[ -f .env ]] && set -a && source .env && set +a

HOST_KIND="$(bash scripts/termux/detect-host.sh)"
if [[ "$HOST_KIND" == "termux-android" && "${TERMUX_BACKEND_ONLY:-1}" == "1" ]]; then
  echo "[termux] Raw Android — backend-only on :${PORT:-8080} (no Next.js SWC)."
  echo "  proot-distro login ubuntu -- bash -lc 'cd $ROOT && npm run termux:dev'"
  exec npm run termux:backend
fi

rm -rf .next 2>/dev/null || true
if [[ ! -f .babelrc ]]; then
  echo '{ "presets": ["next/babel"] }' > .babelrc
fi

echo "[openclaws] Next.js dev on port $PORT (webpack, SWC disabled)"
exec npx next dev --port "$PORT" --no-turbo

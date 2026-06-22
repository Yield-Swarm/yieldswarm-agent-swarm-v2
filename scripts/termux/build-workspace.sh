#!/usr/bin/env bash
# Full YieldSwarm install + build inside proot Ubuntu (avoids Android native postinstall failures).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
REPO_URL="${REPO_URL:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"
WORK_DIR="${WORK_DIR:-$HOME/yieldswarm-agent-swarm-v2}"
SKIP_MATRIX_NATIVE="${SKIP_MATRIX_NATIVE:-1}"

source "$HERE/detect-host.sh" >/dev/null

if [[ "$YIELDSWARM_HOST_KIND" == "termux-android" ]]; then
  echo "[build] Detected raw Termux/Android. Use proot first:" >&2
  echo "  bash scripts/termux/proot-bootstrap.sh" >&2
  echo "  proot-distro login ubuntu -- bash -lc 'bash scripts/termux/build-workspace.sh'" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "[build] Node missing — running install-node-ubuntu.sh"
  bash "$HERE/install-node-ubuntu.sh"
fi

if [[ ! -d "$WORK_DIR/.git" ]]; then
  echo "[build] Cloning into $WORK_DIR"
  git clone "$REPO_URL" "$WORK_DIR"
fi

cd "$WORK_DIR"
git pull --ff-only origin main 2>/dev/null || true

# Packages like @matrix-org/matrix-sdk-crypto-nodejs reject android at postinstall.
# Inside proot Ubuntu, platform reads as linux — no skip needed. For raw android fallback:
if [[ "$SKIP_MATRIX_NATIVE" == "1" ]]; then
  export npm_config_optional=true
  export MATRIX_SDK_CRYPTO_NODEJS_SKIP_INSTALL=1
fi

echo "[build] Installing root dependencies (npm ci)..."
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi

echo "[build] Installing backend..."
(cd backend && npm ci 2>/dev/null || npm install)

echo "[build] Installing frontend (vite)..."
(cd frontend && npm ci 2>/dev/null || npm install)

echo "[build] Running production build..."
npm run build:all

echo "[build] Success. Start backend: npm run dev:backend"

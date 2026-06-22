#!/usr/bin/env bash
# Mining / Akash path on Termux without full Node native build (Python + bash only).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

cd "$ROOT"

echo "[mining] Termux mining-only path — no pnpm/vite/matrix native modules required."

if ! command -v python3 >/dev/null 2>&1; then
  echo "[mining] Install Python in Termux: pkg install python -y" >&2
  exit 1
fi

if [[ ! -f deploy/akash.env ]]; then
  echo "[mining] Copy deploy/akash.env.example → deploy/akash.env and edit wallets." >&2
  exit 1
fi

chmod +x scripts/mining/*.sh scripts/deploy-bittensor.sh scripts/deploy-to-akash.sh 2>/dev/null || true

echo "[mining] Preflight..."
bash scripts/akash-preflight.sh || true

echo "[mining] Fleet status:"
bash scripts/mining/status.sh || true

echo "[mining] To deploy Bittensor SDL: ./scripts/deploy-bittensor.sh"
echo "[mining] For full Node dashboard build, use proot: bash scripts/termux/proot-bootstrap.sh"

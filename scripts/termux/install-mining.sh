#!/usr/bin/env bash
# Termux bootstrap for YieldSwarm 8-instance edge mining fleet.
#
# Run inside Termux on Android:
#   curl -fsSL ... | bash   # or clone repo
#   ./scripts/termux/install-mining.sh
set -euo pipefail

echo "[termux] Installing Termux mining dependencies..."

pkg update -y
pkg install -y python git curl wget proot-distro

# Keep CPU awake while daemon runs (Termux API package)
if ! pkg install -y termux-api 2>/dev/null; then
  echo "[termux] WARN: termux-api not installed — wake lock may be unavailable"
fi

echo "[termux] Optional: proot Ubuntu for xmrig CPU mining"
echo "  proot-distro install ubuntu"
echo "  proot-distro login ubuntu"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
chmod +x "${REPO_ROOT}/scripts/termux/"*.sh 2>/dev/null || true

echo "[termux] Done. Start fleet:"
echo "  cd ${REPO_ROOT}"
echo "  ./scripts/termux/mining-daemon.sh start"

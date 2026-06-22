#!/usr/bin/env bash
# Bootstrap Ubuntu via proot-distro inside Termux (bypasses Android native module wall).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

if ! command -v pkg >/dev/null 2>&1; then
  echo "[termux] This script must run inside Termux (pkg not found)." >&2
  exit 1
fi

echo "[termux] Updating Termux packages and installing proot-distro..."
pkg update -y
pkg install -y proot-distro git curl wget

if ! proot-distro list 2>/dev/null | grep -q '^ubuntu'; then
  echo "[termux] Installing Ubuntu rootfs (one-time, ~300MB)..."
  proot-distro install ubuntu
else
  echo "[termux] Ubuntu rootfs already installed."
fi

cat <<EOF

[termux] Bootstrap complete.

Next — enter Ubuntu and run the workspace build:

  proot-distro login ubuntu -- bash -lc 'curl -fsSL https://raw.githubusercontent.com/Yield-Swarm/yieldswarm-agent-swarm-v2/main/scripts/termux/install-node-ubuntu.sh | bash'

Or from a local clone:

  proot-distro login ubuntu -- bash -lc 'cd /root/yieldswarm-agent-swarm-v2 && bash scripts/termux/build-workspace.sh'

Docs: ${ROOT}/docs/TERMUX_PROOT_BUILD.md

EOF

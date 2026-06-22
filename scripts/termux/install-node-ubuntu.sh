#!/usr/bin/env bash
# Install Node.js 20 + build toolchain inside proot Ubuntu (not on raw Termux).
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
  echo "[ubuntu] Run this inside proot-distro Ubuntu, not raw Termux." >&2
  echo "  proot-distro login ubuntu" >&2
  exit 1
fi

apt-get update -y
apt-get install -y curl ca-certificates git build-essential python3

if ! command -v node >/dev/null 2>&1 || [[ "$(node -p "process.versions.node.split('.')[0]")" -lt 20 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

echo "[ubuntu] node $(node -v) | npm $(npm -v)"

# Optional global CLIs used by some forks (OpenClaw / Matrix stacks)
if [[ "${INSTALL_GLOBAL_CLI:-1}" == "1" ]]; then
  npm install -g pnpm@9 typescript@5
  echo "[ubuntu] pnpm $(pnpm -v 2>/dev/null || echo n/a)"
fi

echo "[ubuntu] Toolchain ready. Clone or cd to repo, then: bash scripts/termux/build-workspace.sh"

#!/usr/bin/env bash
# Termux: install build deps and compile XMRig (one-time, ~10–20 min on ARM).
#
# Usage:
#   termux-setup-storage   # run once manually first
#   ./scripts/termux/xmrig-install.sh
set -euo pipefail

echo "[xmrig-install] Updating Termux packages..."
pkg update -y && pkg upgrade -y

echo "[xmrig-install] Installing build dependencies..."
pkg install -y git clang cmake openssl libuv build-essential tmux htop curl jq python

XMRIG_SRC="${XMRIG_SRC:-$HOME/xmrig}"
if [[ ! -d "${XMRIG_SRC}/.git" ]]; then
  echo "[xmrig-install] Cloning XMRig..."
  git clone https://github.com/xmrig/xmrig.git "${XMRIG_SRC}"
fi

cd "${XMRIG_SRC}"
mkdir -p build && cd build

echo "[xmrig-install] Building (cmake -DWITH_HWLOC=OFF)..."
cmake .. -DWITH_HWLOC=OFF
make -j"$(nproc)"

if [[ -x ./xmrig ]]; then
  echo "[xmrig-install] OK — binary: ${XMRIG_SRC}/build/xmrig"
  ./xmrig --version || true
else
  echo "[xmrig-install] ERROR: build failed" >&2
  exit 1
fi

echo "[xmrig-install] Set: export XMRIG_PATH=${XMRIG_SRC}/build/xmrig"

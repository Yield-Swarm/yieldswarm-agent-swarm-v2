#!/usr/bin/env bash
# Stop Termux XMRig tmux mining session.
set -euo pipefail
SESSION="${XMRIG_TMUX_SESSION:-mining}"
if tmux has-session -t "${SESSION}" 2>/dev/null; then
  tmux kill-session -t "${SESSION}"
  echo "[xmrig] killed session ${SESSION}"
else
  pkill -f xmrig 2>/dev/null || true
  echo "[xmrig] no tmux session; sent pkill xmrig"
fi
if command -v termux-wake-unlock >/dev/null 2>&1; then
  termux-wake-unlock
fi

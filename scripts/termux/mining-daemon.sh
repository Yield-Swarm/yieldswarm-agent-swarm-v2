#!/usr/bin/env bash
# Termux mining daemon — 8 × (16GB RAM / 128GB SSD) multi-mining instances.
#
# Usage (in Termux):
#   ./scripts/termux/mining-daemon.sh start     # background 8-instance fleet
#   ./scripts/termux/mining-daemon.sh stop
#   ./scripts/termux/mining-daemon.sh status
#   ./scripts/termux/mining-daemon.sh foreground  # blocking daemon (wake-lock)
#
# Env:
#   TERMUX_INSTANCE_COUNT=8
#   TERMUX_RAM_MB=16384
#   TERMUX_STORAGE_GB=128
#   MINING_ROOT_PRL / MINING_WALLET_* / GRASS_NODE_KEYS
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"

TERMUX_INSTANCE_COUNT="${TERMUX_INSTANCE_COUNT:-8}"
TERMUX_RAM_MB="${TERMUX_RAM_MB:-16384}"
TERMUX_STORAGE_GB="${TERMUX_STORAGE_GB:-128}"
PID_FILE="${REPO_ROOT}/.run/termux/daemon.pid"
LOG_FILE="${REPO_ROOT}/.run/termux/daemon.log"

mkdir -p "${REPO_ROOT}/.run/termux"

wake_lock() {
  if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock
    echo "[termux] wake-lock acquired"
  fi
}

wake_unlock() {
  if command -v termux-wake-unlock >/dev/null 2>&1; then
    termux-wake-unlock
    echo "[termux] wake-lock released"
  fi
}

cmd="${1:-status}"
shift || true

case "${cmd}" in
  start)
    wake_lock
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
      echo "[termux] daemon already running pid=$(cat "${PID_FILE}")"
      exit 0
    fi
    export TERMUX_INSTANCE_COUNT TERMUX_RAM_MB TERMUX_STORAGE_GB
    export MINING_DRY_RUN=0
    nohup python3 -m mining.termux_fleet launch --live >>"${LOG_FILE}" 2>&1 &
    echo $! > "${PID_FILE}"
    echo "[termux] started ${TERMUX_INSTANCE_COUNT} instances — pid=$(cat "${PID_FILE}")"
    echo "[termux] log: ${LOG_FILE}"
    ;;
  stop)
    wake_unlock
    if [[ -f "${PID_FILE}" ]]; then
      kill "$(cat "${PID_FILE}")" 2>/dev/null || true
      rm -f "${PID_FILE}"
    fi
    python3 -m mining.termux_fleet stop
    echo "[termux] stopped"
    ;;
  status)
    python3 -m mining.termux_fleet status
    ;;
  foreground|daemon)
    wake_lock
    trap wake_unlock EXIT
    export TERMUX_INSTANCE_COUNT TERMUX_RAM_MB TERMUX_STORAGE_GB
    export MINING_DRY_RUN=0
    exec python3 -m mining.termux_fleet daemon --live
    ;;
  config)
    python3 -m mining.termux_fleet config
    ;;
  *)
    echo "Usage: $0 {start|stop|status|foreground|config}" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
# Termux — stop mining orchestrator cleanly.
set -euo pipefail

REPO_DIR="${YIELDSWARM_REPO:-$HOME/yieldswarm-agent-swarm-v2}"
cd "${REPO_DIR}"

export PYTHONPATH="${REPO_DIR}${PYTHONPATH:+:${PYTHONPATH}}"
export MINING_RUN_DIR="${MINING_RUN_DIR:-${REPO_DIR}/.run/mining}"

python3 -m mining stop 2>&1 || true

PID_FILE="${MINING_RUN_DIR}/orchestrator.pid"
if [[ -f "${PID_FILE}" ]]; then
  pid="$(cat "${PID_FILE}")"
  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
    echo "stopped orchestrator pid ${pid}"
  fi
  rm -f "${PID_FILE}"
fi

if command -v termux-wake-unlock >/dev/null 2>&1; then
  termux-wake-unlock && echo "termux-wake-unlock: OK"
fi

python3 -m mining status

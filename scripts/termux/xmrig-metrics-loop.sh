#!/usr/bin/env bash
# Background loop: collect XMRig metrics every N seconds for Trident telemetry bridge.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INTERVAL="${XMRIG_METRICS_INTERVAL:-30}"
PID_FILE="${REPO_ROOT}/.run/termux/xmrig-collector.pid"

mkdir -p "${REPO_ROOT}/.run/termux"

if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
  echo "[xmrig-collector] already running pid=$(cat "${PID_FILE}")"
  exit 0
fi

(
  while true; do
    "${REPO_ROOT}/scripts/termux/xmrig-status.sh" >/dev/null 2>&1 || true
    sleep "${INTERVAL}"
  done
) &
echo $! > "${PID_FILE}"
echo "[xmrig-collector] started pid=$(cat "${PID_FILE}") interval=${INTERVAL}s"

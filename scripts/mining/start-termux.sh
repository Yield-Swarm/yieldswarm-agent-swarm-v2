#!/usr/bin/env bash
# Termux / Android — start unified mining orchestrator with correct paths.
#
# IMPORTANT: Never use backslash before tilde (\~). Use $HOME or ~/ only.
#
# Usage:
#   cd ~/yieldswarm-agent-swarm-v2
#   ./scripts/mining/start-termux.sh
set -euo pipefail

REPO_DIR="${YIELDSWARM_REPO:-$HOME/yieldswarm-agent-swarm-v2}"

if [[ ! -d "${REPO_DIR}/mining" ]]; then
  echo "ERROR: repo not found at ${REPO_DIR}" >&2
  echo "  Fix: cd ~/yieldswarm-agent-swarm-v2   (no backslash before ~)" >&2
  exit 1
fi

cd "${REPO_DIR}"
echo "=== YIELDSWARM TERMUX MINING START ==="
echo "repo: $(pwd)"

# Operator config (never use \~ in these paths)
if [[ -f "${HOME}/.config/yieldswarm/nexus.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${HOME}/.config/yieldswarm/nexus.env"
  set +a
  echo "loaded ${HOME}/.config/yieldswarm/nexus.env"
fi

for f in deploy/akash.env deploy/config.env .env; do
  if [[ -f "${f}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${f}"
    set +a
    echo "loaded ${f}"
    break
  fi
done

if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock && echo "termux-wake-lock: ON"
else
  echo "note: termux-wake-lock not found (not Termux?)"
fi

export PYTHONPATH="${REPO_DIR}${PYTHONPATH:+:${PYTHONPATH}}"
export MINING_RUN_DIR="${MINING_RUN_DIR:-${REPO_DIR}/.run/mining}"
mkdir -p "${MINING_RUN_DIR}"

echo "stopping existing miners..."
python3 -m mining stop 2>&1 || true
sleep 2

LOG_FILE="${MINING_RUN_DIR}/orchestrator.log"
PID_FILE="${MINING_RUN_DIR}/orchestrator.pid"

nohup python3 -m mining start >"${LOG_FILE}" 2>&1 &
echo $! >"${PID_FILE}"
echo "Launched with PID $(cat "${PID_FILE}")"
echo "log: ${LOG_FILE}"

sleep 5
python3 -m mining status

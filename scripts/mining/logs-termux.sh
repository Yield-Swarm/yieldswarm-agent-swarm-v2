#!/usr/bin/env bash
# Tail mining orchestrator log (Termux-safe paths).
set -euo pipefail

REPO_DIR="${YIELDSWARM_REPO:-$HOME/yieldswarm-agent-swarm-v2}"
LOG="${MINING_RUN_DIR:-${REPO_DIR}/.run/mining}/orchestrator.log"

if [[ ! -f "${LOG}" ]]; then
  echo "log not found: ${LOG}" >&2
  exit 1
fi

tail -n "${1:-30}" "${LOG}"

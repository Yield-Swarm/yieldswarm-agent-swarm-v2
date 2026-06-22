#!/usr/bin/env bash
# depin_edge_orchestrate.sh — Run all 4 DePIN edge tasks in order (Termux / local hub)
#
# Usage:
#   export VAULT_ADDR=... VAULT_TOKEN=...   # Task 2 only — never commit
#   ./scripts/edge/depin_edge_orchestrate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${YIELDSWARM_LOG_DIR:-$HOME/yieldswarm-logs}"
export YIELDSWARM_REPO="${REPO_ROOT}"
export YIELDSWARM_LOG_DIR="${LOG_DIR}"

mkdir -p "${LOG_DIR}"
cd "${REPO_ROOT}"

run() {
  local name="$1" script="$2"
  echo "======== ${name} ========"
  bash "${script}"
}

chmod +x scripts/edge/*.sh 2>/dev/null || true

run "Task 1 — Edge gateway normalizer" scripts/edge/edge_gateway_normalizer.sh

if [[ -n "${VAULT_ADDR:-}" ]] && [[ -n "${VAULT_TOKEN:-}${VAULT_ROLE_ID:-}" ]]; then
  run "Task 2 — Vault runtime export" scripts/edge/vault_runtime_export.sh
else
  echo "SKIP Task 2 — set VAULT_ADDR + VAULT_TOKEN or AppRole"
fi

run "Task 3 — W3bstream prover verify" scripts/edge/w3bstream_prover_verify.sh
run "Task 4 — WAN failover monitor" scripts/edge/wan_failover_monitor.sh

echo "======== Telemetry audit ========"
head -n 5 "${LOG_DIR}"/*.log 2>/dev/null || echo "No logs yet at ${LOG_DIR}"

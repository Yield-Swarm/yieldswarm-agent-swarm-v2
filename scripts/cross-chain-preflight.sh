#!/usr/bin/env bash
# Cross-chain execution preflight — GO/NO-GO before live strategies
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

log() { echo "[cross-chain-preflight] $*"; }
PASS=0; FAIL=0

check() {
  if "$@"; then log "PASS $*"; PASS=$((PASS+1)); else log "FAIL $*"; FAIL=$((FAIL+1)); fi
}

log "=== Cross-Chain Execution Preflight ==="
check test -f services/cross_chain/executor.py
check test -f agents/cross_chain_executor.py
check test -f config/cross_chain/strategies.yaml
check test -f contracts/hooks/YieldSwarmAuctionHook.sol
check test -f backend/src/adapters/crossChain.js
check python3 -c "from services.cross_chain.executor import run_scheduled_strategies; run_scheduled_strategies(shard_id=0)"

if [[ "${CROSS_CHAIN_DRY_RUN:-1}" == "0" ]]; then
  log "Live mode — checking API keys..."
  [[ -n "${JUPITER_API_KEY:-}" ]] && log "PASS JUPITER_API_KEY" || log "WARN JUPITER_API_KEY unset"
  [[ -n "${DYDX_API_KEY:-}" ]] && log "PASS DYDX_API_KEY" || log "WARN DYDX_API_KEY unset"
fi

log "Summary: ${PASS} pass, ${FAIL} fail"
[[ "${FAIL}" -eq 0 ]]

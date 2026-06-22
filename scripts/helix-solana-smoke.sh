#!/usr/bin/env bash
# Helix Solana smoke — verify programs, SDK, and API wiring from repo root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

log() { printf '[helix-solana-smoke] %s\n' "$*"; }
PASS=0; FAIL=0

check() {
  if "$@"; then log "PASS $*"; PASS=$((PASS+1)); else log "FAIL $*"; FAIL=$((FAIL+1)); fi
}

log "repo: $ROOT"
log "branch: $(git branch --show-current 2>/dev/null || echo unknown)"

check test -f Anchor.toml
check test -f programs/cross_chain/src/lib.rs
check test -f programs/swarm_ops/src/lib.rs
check test -f sdk/helix/src/client.ts
check test -f integrations/solana/useCrossChainYield.ts
check grep -q 'trigger_remote_harvest' programs/cross_chain/src/lib.rs
check grep -q 'authorize_harvest' programs/swarm_ops/src/lib.rs
check grep -q '9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt' Anchor.toml

if command -v anchor >/dev/null 2>&1; then
  log "anchor: $(anchor --version)"
  check anchor keys list 2>/dev/null | grep -q cross_chain || true
else
  log "WARN anchor CLI not installed — skip build"
fi

if curl -sfS http://127.0.0.1:8080/api/health >/dev/null 2>&1; then
  check curl -sfS http://127.0.0.1:8080/api/cross-chain/health | grep -q live
  check curl -sfS http://127.0.0.1:8080/api/helix/treasury >/dev/null
  check curl -sfS http://127.0.0.1:8080/api/nexus/status >/dev/null
else
  log "WARN backend not on :8080 — skip API checks"
fi

log "Summary: $PASS pass, $FAIL fail"
[[ "$FAIL" -eq 0 ]]

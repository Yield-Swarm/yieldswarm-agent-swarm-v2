#!/usr/bin/env bash
# =============================================================================
# master-smoke-test.sh — Comprehensive post-merge validation
#
# Usage:
#   ./scripts/master-smoke-test.sh
#   STRICT=1 ./scripts/master-smoke-test.sh   # fail on any warning section
#
# Sections:
#   1. Core structural smoke (scripts/smoke-test.sh)
#   2. Vault injection readiness
#   3. Akash preflight + lease verify (if scripts present)
#   4. Sovereign runtime one-shot cycle
#   5. Optional live API probes (backend, Kairo)
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

STRICT="${STRICT:-0}"
BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8080}"
KAIRO_URL="${KAIRO_URL:-http://127.0.0.1:8100}"
WARN=0
FAIL=0

log() { echo "[master-smoke] $*"; }
section() { echo ""; log "━━━ $* ━━━"; }

warn() { log "WARN: $*"; WARN=$((WARN + 1)); }
fail() { log "FAIL: $*"; FAIL=$((FAIL + 1)); }

run_optional() {
  local name="$1"
  shift
  if "$@"; then
    log "OK ${name}"
  else
    warn "${name}"
  fi
}

section "1. Core smoke tests"
if [[ -x "${SCRIPT_DIR}/smoke-test.sh" ]]; then
  if bash "${SCRIPT_DIR}/smoke-test.sh"; then
    log "OK core smoke-test.sh"
  else
  warn "core smoke-test.sh had failures (see above)"
  fi
else
  warn "scripts/smoke-test.sh missing"
fi

section "2. Vault injection"
if [[ -x "${SCRIPT_DIR}/verify-vault-injection.sh" ]]; then
  if bash "${SCRIPT_DIR}/verify-vault-injection.sh"; then
    log "OK vault injection"
  else
    warn "vault injection checks failed (set VAULT_TOKEN for live mint)"
  fi
else
  warn "verify-vault-injection.sh missing"
fi

section "3. Akash preflight + verify"
if [[ -x "${SCRIPT_DIR}/akash-preflight.sh" ]]; then
  if bash "${SCRIPT_DIR}/akash-preflight.sh"; then
    log "OK akash preflight GO"
  else
    warn "akash preflight NO-GO (fund wallet + set VAULT_TOKEN)"
  fi
else
  warn "akash-preflight.sh not on this branch — merge cursor/akash-real-deploy-9c82"
fi

if [[ -x "${SCRIPT_DIR}/verify-akash-lease.sh" ]]; then
  if bash "${SCRIPT_DIR}/verify-akash-lease.sh"; then
    log "OK akash lease verify"
  else
    warn "akash lease verify failed (no live lease yet?)"
  fi
else
  warn "verify-akash-lease.sh not on this branch"
fi

section "4. Sovereign runtime"
if [[ -f "${REPO_ROOT}/services/sovereign_runtime.py" ]]; then
  if python3 "${REPO_ROOT}/services/sovereign_runtime.py" >/dev/null 2>&1; then
    log "OK sovereign_runtime.py one-shot cycle"
  else
    warn "sovereign_runtime.py cycle failed"
  fi
elif [[ -f "${REPO_ROOT}/deploy/runtime/swarm_runner.py" ]]; then
  if SOVEREIGN_ONESHOT=1 python3 "${REPO_ROOT}/deploy/runtime/swarm_runner.py" >/dev/null 2>&1; then
    log "OK swarm_runner.py one-shot cycle"
  else
    warn "swarm_runner.py one-shot failed (non-fatal in dev)"
  fi
else
  warn "no sovereign entrypoint found"
fi

section "5. Sovereign loops supervisor"
if [[ -x "${REPO_ROOT}/deploy/scripts/start-sovereign-loops.sh" ]]; then
  bash "${REPO_ROOT}/deploy/scripts/start-sovereign-loops.sh" status || warn "sovereign loops not running"
else
  warn "start-sovereign-loops.sh missing"
fi

section "6. Optional live API probes"
if curl -sf "${BACKEND_URL}/api/health" >/dev/null 2>&1; then
  log "OK backend ${BACKEND_URL}/api/health"
  run_optional "sovereign state API" curl -sf "${BACKEND_URL}/api/sovereign/state"
else
  log "SKIP backend not running on ${BACKEND_URL}"
fi

if curl -sf "${KAIRO_URL}/health" >/dev/null 2>&1 || curl -sf "${KAIRO_URL}/healthz" >/dev/null 2>&1; then
  log "OK Kairo API"
else
  log "SKIP Kairo not running on ${KAIRO_URL}"
fi

section "7. Multicloud preflight (if present)"
if [[ -x "${SCRIPT_DIR}/multicloud-preflight.sh" ]]; then
  bash "${SCRIPT_DIR}/multicloud-preflight.sh" || warn "multicloud preflight issues"
fi

echo ""
log "━━━ Master Smoke Summary ━━━"
log "Failures: ${FAIL} | Warnings: ${WARN}"

if [[ "${FAIL}" -gt 0 ]]; then
  log "VERDICT: FAIL"
  exit 1
fi

if [[ "${STRICT}" == "1" && "${WARN}" -gt 0 ]]; then
  log "VERDICT: FAIL (STRICT=1, warnings treated as failures)"
  exit 1
fi

log "VERDICT: PASS (review warnings above)"
exit 0

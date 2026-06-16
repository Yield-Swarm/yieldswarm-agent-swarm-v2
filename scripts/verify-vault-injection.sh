#!/usr/bin/env bash
# =============================================================================
# verify-vault-injection.sh — Validate Vault → Akash injection readiness
#
# Usage:
#   export VAULT_ADDR=... VAULT_TOKEN=...
#   ./scripts/verify-vault-injection.sh
#   ./scripts/verify-vault-injection.sh --json
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

log() { echo "[verify-vault-injection] $*"; }

VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
SDL="${AKASH_SDL:-${REPO_ROOT}/deploy/deploy-swarm-monolith.yaml}"

PASS=0
FAIL=0
WARN=0

check() {
  local status="$1" name="$2" detail="$3"
  case "${status}" in
    pass) PASS=$((PASS + 1)); log "PASS ${name}: ${detail}" ;;
    fail) FAIL=$((FAIL + 1)); log "FAIL ${name}: ${detail}" ;;
    warn) WARN=$((WARN + 1)); log "WARN ${name}: ${detail}" ;;
  esac
}

# Vault CLI + reachability
if command -v vault >/dev/null 2>&1; then
  if vault status -address="${VAULT_ADDR}" >/dev/null 2>&1; then
    check pass vault_reachable "${VAULT_ADDR}"
  else
    check fail vault_reachable "cannot reach ${VAULT_ADDR}"
  fi
else
  check warn vault_cli "vault CLI not installed"
fi

# Token present
if [[ -n "${VAULT_TOKEN:-}" || -f "${VAULT_TOKEN_FILE:-/run/secrets/vault-token}" ]]; then
  check pass vault_token "token available"
else
  check warn vault_token "VAULT_TOKEN not set (required for live mint)"
fi

# Policy + templates
[[ -f "${REPO_ROOT}/vault/policies/akash-runtime.hcl" ]] \
  && check pass policy "vault/policies/akash-runtime.hcl" \
  || check fail policy "akash-runtime.hcl missing"

[[ -f "${REPO_ROOT}/akash/vault-agent.hcl" ]] \
  && check pass vault_agent "akash/vault-agent.hcl" \
  || check warn vault_agent "akash/vault-agent.hcl missing"

[[ -d "${REPO_ROOT}/akash/templates" ]] \
  && check pass templates "akash/templates/ present" \
  || check warn templates "akash/templates/ missing"

# Bootstrap helper
if [[ -f "${SCRIPT_DIR}/lib/vault-akash-bootstrap.sh" ]]; then
  check pass bootstrap_lib "scripts/lib/vault-akash-bootstrap.sh"
  # shellcheck source=scripts/lib/vault-akash-bootstrap.sh
  source "${SCRIPT_DIR}/lib/vault-akash-bootstrap.sh" 2>/dev/null || true
  if vault_sdl_needs_runtime_secrets "${SDL}" 2>/dev/null; then
    check pass sdl_vault_refs "SDL references Vault bootstrap env vars"
  else
    check warn sdl_vault_refs "SDL may not reference VAULT_WRAPPED_SECRET_ID"
  fi
else
  check fail bootstrap_lib "vault-akash-bootstrap.sh missing"
fi

# Live mint (only when token set)
if [[ -n "${VAULT_TOKEN:-}" ]] && command -v vault >/dev/null 2>&1; then
  export VAULT_ADDR
  if vault read -format=json "auth/approle/role/${VAULT_AKASH_ROLE}/role-id" >/dev/null 2>&1; then
    check pass approle "${VAULT_AKASH_ROLE} AppRole readable"
  else
    check fail approle "cannot read AppRole ${VAULT_AKASH_ROLE}"
  fi
fi

VERDICT="GO"
[[ "${FAIL}" -gt 0 ]] && VERDICT="NO-GO"

if [[ "${JSON_MODE}" -eq 1 ]]; then
  jq -nc --arg verdict "${VERDICT}" --argjson pass "${PASS}" --argjson fail "${FAIL}" --argjson warn "${WARN}" \
    '{verdict:$verdict, pass:$pass, fail:$fail, warn:$warn}'
else
  log "=== Summary: ${PASS} pass, ${WARN} warn, ${FAIL} fail → ${VERDICT} ==="
fi

[[ "${VERDICT}" == "GO" ]]

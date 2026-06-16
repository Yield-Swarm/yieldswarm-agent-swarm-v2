#!/usr/bin/env bash
# =============================================================================
# multicloud-preflight.sh — GO/NO-GO across Vault, Akash, and optional cloud APIs
#
# Usage:
#   ./scripts/multicloud-preflight.sh
#   ./scripts/multicloud-preflight.sh --json
#
# Exit 0 = GO (Akash path ready); exit 1 = NO-GO
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"
JSON_MODE=0
[[ "${1:-}" == "--json" ]] && { JSON_MODE=1; shift; }

declare -a CHECKS=()
declare -a FIXES=()
GO=true

log() { echo "[multicloud-preflight] $*"; }

add_check() {
  local id="$1" status="$2" detail="$3" fix="${4:-}"
  CHECKS+=("$(jq -nc --arg id "$id" --arg status "$status" --arg detail "$detail" --arg fix "$fix" \
    '{id:$id, status:$status, detail:$detail, fix:$fix}')")
  if [[ "$status" == "fail" ]]; then
    GO=false
    [[ -n "$fix" ]] && FIXES+=("$fix")
  fi
}

# --- Vault ---
VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
if command -v vault >/dev/null 2>&1; then
  if vault status -address="${VAULT_ADDR}" >/dev/null 2>&1; then
    add_check "vault_reachable" "pass" "Vault reachable at ${VAULT_ADDR}"
  else
    add_check "vault_reachable" "warn" "Vault not reachable (set VAULT_TOKEN)" \
      "export VAULT_ADDR=${VAULT_ADDR} && export VAULT_TOKEN=<token>"
  fi
else
  add_check "vault_cli" "warn" "vault CLI not installed" "install HashiCorp Vault CLI"
fi

if [[ -n "${VAULT_TOKEN:-}" || -f "${VAULT_TOKEN_FILE:-/run/secrets/vault-token}" ]]; then
  add_check "vault_token" "pass" "Vault token present"
else
  add_check "vault_token" "warn" "VAULT_TOKEN not set" \
    "export VAULT_TOKEN=<token>  # never commit"
fi

# --- Akash (delegate to akash-preflight if present) ---
if [[ -x "${SCRIPT_DIR}/akash-preflight.sh" ]]; then
  if "${SCRIPT_DIR}/akash-preflight.sh" >/dev/null 2>&1; then
    add_check "akash_preflight" "pass" "Akash preflight GO"
  else
    add_check "akash_preflight" "fail" "Akash preflight NO-GO" \
      "./scripts/akash-preflight.sh  # follow fix commands"
  fi
else
  add_check "akash_preflight" "warn" "akash-preflight.sh missing"
fi

# --- Optional cloud API keys (warn only — not blocking) ---
check_optional_key() {
  local id="$1" env_var="$2" vault_path="$3"
  if [[ -n "${!env_var:-}" ]]; then
    add_check "${id}" "pass" "${env_var} set in environment"
  else
    add_check "${id}" "warn" "${env_var} not set" \
      "vault kv get ${vault_path} or export ${env_var}=..."
  fi
}

check_optional_key "runpod_key" "RUNPOD_API_KEY" "kv/yieldswarm/cloud/runpod"
check_optional_key "vast_key" "VAST_API_KEY" "kv/yieldswarm/cloud/vast"
check_optional_key "azure_creds" "AZURE_SUBSCRIPTION_ID" "kv/yieldswarm/cloud/azure"
check_optional_key "gcp_creds" "GOOGLE_APPLICATION_CREDENTIALS" "kv/yieldswarm/cloud/gcp"
check_optional_key "aws_creds" "AWS_ACCESS_KEY_ID" "kv/yieldswarm/cloud/aws"

# --- Budget config ---
if [[ -f "${REPO_ROOT}/config/multicloud/budgets.env" ]]; then
  add_check "budget_config" "pass" "config/multicloud/budgets.env present"
else
  add_check "budget_config" "warn" "No budgets.env — using defaults" \
    "cp config/multicloud/budgets.env.example config/multicloud/budgets.env"
fi

# --- MCP config ---
if [[ -f "${REPO_ROOT}/.cursor/mcp-config-top12.json" ]]; then
  add_check "mcp_config" "pass" ".cursor/mcp-config-top12.json present"
else
  add_check "mcp_config" "warn" "MCP config missing" \
    "see docs/CURSOR_CLOUD_SETUP.md"
fi

mkdir -p "${RUN_DIR}"

if [[ "${JSON_MODE}" -eq 1 ]]; then
  jq -nc \
    --argjson checks "$(printf '%s\n' "${CHECKS[@]}" | jq -s '.')" \
    --arg verdict "$( [[ "${GO}" == true ]] && echo GO || echo NO-GO )" \
    '{verdict:$verdict, checks:$checks}'
else
  log "=== Multi-Cloud Preflight ==="
  for c in "${CHECKS[@]}"; do
    echo "${c}" | jq -r '"[\(.status | ascii_upcase)] \(.id): \(.detail)"'
  done
  log ""
  if [[ "${GO}" == true ]]; then
    log "VERDICT: GO (Akash path ready)"
  else
    log "VERDICT: NO-GO"
    log "Fixes:"
    printf '  - %s\n' "${FIXES[@]}"
  fi
fi

[[ "${GO}" == true ]]

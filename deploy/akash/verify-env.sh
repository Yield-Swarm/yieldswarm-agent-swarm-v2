#!/usr/bin/env bash
# Verify Vault + Akash environment before deploying.
# Run after exporting VAULT_* vars (and optionally after setup-auth.sh).
#
# Usage:
#   export VAULT_ADDR=... VAULT_ROLE_ID=... VAULT_SECRET_ID=...
#   ./deploy/akash/verify-env.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0
WARN=0

ok()   { printf '  ✅ %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  ❌ %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }
warn() { printf '  ⚠️  %s\n' "$*"; WARN=$((WARN + 1)); }

section() { printf '\n── %s ──\n' "$*"; }

section "Vault connectivity"
for var in VAULT_ADDR VAULT_ROLE_ID VAULT_SECRET_ID; do
  if [[ -n "${!var:-}" ]]; then ok "${var} is set"; else fail "${var} is not set"; fi
done

if command -v vault >/dev/null 2>&1; then
  ok "vault CLI installed ($(vault version 2>/dev/null | head -1))"
  if vault status >/dev/null 2>&1; then
    ok "Vault reachable and unsealed"
  else
    fail "Vault not reachable at ${VAULT_ADDR:-<unset>}"
  fi
else
  warn "vault CLI not installed (optional for deploy if secrets pre-exported)"
fi

section "Akash CLI (provider-services)"
if command -v provider-services >/dev/null 2>&1; then
  ok "provider-services installed ($(provider-services version 2>/dev/null || echo unknown))"
else
  fail "provider-services not found — install: https://akash.network/docs/developers/deployment/cli/installation-guide/"
fi

if command -v akash >/dev/null 2>&1; then
  warn "legacy 'akash' CLI detected — deploy.sh uses provider-services (JWT default)"
else
  ok "no legacy akash CLI conflict"
fi

section "Akash authentication (AEP-63/64)"
if [[ "${AKASH_AUTH_CONFIGURED:-false}" == "true" ]]; then
  ok "setup-auth.sh already ran (AKASH_AUTH_CONFIGURED=true)"
else
  warn "setup-auth.sh not sourced — running now"
  # shellcheck source=setup-auth.sh
  source "${SCRIPT_DIR}/setup-auth.sh"
  configure_akash_auth
fi

printf '  auth_method:      %s\n' "${AKASH_AUTH_METHOD:-unset}"
printf '  key_name:         %s\n' "${AKASH_KEY_NAME:-unset}"
printf '  keyring_backend:  %s\n' "${AKASH_KEYRING_BACKEND:-unset}"
printf '  account_address:  %s\n' "${AKASH_ACCOUNT_ADDRESS:-unset}"
printf '  chain_id:         %s\n' "${AKASH_CHAIN_ID:-unset}"
printf '  node:             %s\n' "${AKASH_NODE:-unset}"

if [[ "${AKASH_AUTH_METHOD:-}" == "jwt" || "${AKASH_AUTH_METHOD:-}" == "keyring" ]]; then
  ok "JWT-capable auth mode (${AKASH_AUTH_METHOD}) — provider-services auto-mints tokens"
fi

if [[ -n "${AKASH_JWT:-}" ]]; then
  ok "AKASH_JWT set (pre-generated provider token)"
else
  ok "AKASH_JWT not required — CLI generates short-lived JWTs at request time"
fi

section "Account balance"
if [[ -n "${AKASH_ACCOUNT_ADDRESS:-}" && -n "${AKASH_NODE:-}" ]]; then
  if balance_json="$(provider-services query bank balances --node "${AKASH_NODE}" "${AKASH_ACCOUNT_ADDRESS}" -o json 2>/dev/null)"; then
    uakt="$(echo "${balance_json}" | jq -r '[.balances[]? | select(.denom=="uakt") | .amount] | first // "0"')"
    akt="$(echo "${uakt}" | awk '{printf "%.4f", $1/1000000}')"
    printf '  balance: %s uAKT (%s AKT)\n' "${uakt}" "${akt}"
    if [[ "${uakt}" -ge 500000 ]]; then
      ok "balance >= 0.5 AKT (deployment minimum)"
    else
      fail "balance below 0.5 AKT minimum — fund ${AKASH_ACCOUNT_ADDRESS}"
    fi
  else
    warn "could not query balance (RPC may be unreachable)"
  fi
else
  fail "cannot check balance — account address or node missing"
fi

section "Vault secret validation"
if [[ -f "${SCRIPT_DIR}/../../infra/vault/scripts/validate-secrets.sh" ]]; then
  if VAULT_TOKEN="$(curl -sS -X POST -H 'Content-Type: application/json' \
      -d "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"${VAULT_SECRET_ID}\"}" \
      "${VAULT_ADDR}/v1/auth/approle/login" | jq -r '.auth.client_token')" \
     && [[ -n "${VAULT_TOKEN}" && "${VAULT_TOKEN}" != "null" ]]; then
    export VAULT_TOKEN
    if "${SCRIPT_DIR}/../../infra/vault/scripts/validate-secrets.sh" >/dev/null 2>&1; then
      ok "all required Vault paths and AppRoles present"
    else
      warn "Vault validate-secrets reported warnings (check REPLACE_ME placeholders)"
    fi
  else
    fail "Vault AppRole login failed during validation"
  fi
fi

section "Summary"
printf '\n  Passed: %s  Failed: %s  Warnings: %s\n\n' "${PASS}" "${FAIL}" "${WARN}"

if [[ "${FAIL}" -gt 0 ]]; then
  echo "Fix failures above before deploying." >&2
  exit 1
fi

echo "Environment ready. Deploy with: ./deploy/akash/deploy.sh"
exit 0

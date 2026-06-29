#!/usr/bin/env bash
# Configure Akash authentication from Vault secrets (AEP-63/64 compatible).
#
# Auth modes (set in yieldswarm/akash → auth_method):
#   jwt     — default; provider-services v0.10+ auto-generates short-lived JWTs (recommended)
#   keyring — legacy file keyring (test/os); same key import, no manual JWT export
#   mtls    — certificate-based provider auth (optional fallback)
#
# Usage (after exporting VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID):
#   source deploy/akash/setup-auth.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vault-fetch.sh
source "${SCRIPT_DIR}/lib/vault-fetch.sh"

log() { printf '[akash-auth] %s\n' "$*" >&2; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "ERROR: required command not found: $1"
    return 1
  fi
}

import_key_from_mnemonic() {
  local key_name="$1"
  local mnemonic="$2"
  local backend="$3"

  if provider-services keys show "${key_name}" -a --keyring-backend "${backend}" >/dev/null 2>&1; then
    log "Key '${key_name}' already present in ${backend} keyring"
    return 0
  fi

  log "Importing Akash key '${key_name}' into ${backend} keyring (ephemeral)"
  printf '%s\n' "${mnemonic}" | provider-services keys add "${key_name}" \
    --recover \
    --keyring-backend "${backend}" \
    >/dev/null
}

configure_akash_auth() {
  require_cmd jq
  require_cmd curl
  require_cmd provider-services

  vault_deploy_login
  local secrets
  secrets="$(vault_fetch_akash_secrets)"

  local auth_method key_name keyring_backend mnemonic
  auth_method="$(echo "${secrets}" | jq -r '.auth_method // "jwt"')"
  key_name="$(echo "${secrets}" | jq -r '.key_name // "yieldswarm-admin"')"
  keyring_backend="$(echo "${secrets}" | jq -r '.keyring_backend // "test"')"
  mnemonic="$(echo "${secrets}" | jq -r '.wallet_mnemonic // empty')"

  # Env fallback for Codespaces / CI when Vault has placeholders
  if [[ -z "${mnemonic}" || "${mnemonic}" == "REPLACE_ME" || "${mnemonic}" == "test mnemonic words" ]]; then
    if [[ -n "${AKASH_WALLET_MNEMONIC:-}" ]]; then
      mnemonic="${AKASH_WALLET_MNEMONIC}"
      log "Using AKASH_WALLET_MNEMONIC from environment"
    elif provider-services keys show "${AKASH_KEY_NAME:-yieldswarm-admin}" -a \
        --keyring-backend "${AKASH_KEYRING_BACKEND:-test}" >/dev/null 2>&1; then
      key_name="${AKASH_KEY_NAME:-yieldswarm-admin}"
      keyring_backend="${AKASH_KEYRING_BACKEND:-test}"
      log "Using existing keyring key '${key_name}'"
      mnemonic=""
    else
      log "ERROR: wallet_mnemonic missing in Vault and AKASH_WALLET_MNEMONIC not set"
      return 1
    fi
  fi

  auth_method="$(echo "${secrets}" | jq -r '.auth_method // "jwt"')"
  key_name="${AKASH_KEY_NAME:-$(echo "${secrets}" | jq -r '.key_name // "yieldswarm-admin"')}"
  keyring_backend="${AKASH_KEYRING_BACKEND:-$(echo "${secrets}" | jq -r '.keyring_backend // "test"')}"
  export AKASH_AUTH_METHOD="${auth_method}"
  export AKASH_KEY_NAME="${key_name}"
  export AKASH_KEYRING_BACKEND="${keyring_backend}"
  export AKASH_CHAIN_ID="${AKASH_CHAIN_ID:-$(echo "${secrets}" | jq -r '.chain_id // "akashnet-2"')}"
  export AKASH_NODE="${AKASH_NODE:-$(echo "${secrets}" | jq -r '.rpc_endpoint // "https://rpc.akt.dev/rpc"')}"
  export AKASH_GAS_PRICES="$(echo "${secrets}" | jq -r '.gas_prices // "0.025uakt"')"
  export AKASH_GAS="${AKASH_GAS:-auto}"
  export AKASH_GAS_ADJUSTMENT="${AKASH_GAS_ADJUSTMENT:-1.5}"
  export AKASH_SIGN_MODE="${AKASH_SIGN_MODE:-amino-json}"

  case "${auth_method}" in
    jwt|keyring)
      if [[ -n "${mnemonic}" ]]; then
        import_key_from_mnemonic "${key_name}" "${mnemonic}" "${keyring_backend}"
      fi
      export AKASH_ACCOUNT_ADDRESS="$(
        provider-services keys show "${key_name}" -a --keyring-backend "${keyring_backend}"
      )"
      log "Auth: ${auth_method} (provider-services auto-JWT enabled)"
      ;;
    mtls)
      if [[ -n "${mnemonic}" ]]; then
        import_key_from_mnemonic "${key_name}" "${mnemonic}" "${keyring_backend}"
      fi
      export AKASH_ACCOUNT_ADDRESS="$(
        provider-services keys show "${key_name}" -a --keyring-backend "${keyring_backend}"
      )"
      export AKASH_CERT_PATH="$(echo "${secrets}" | jq -r '.certificate_path // empty')"
      export AKASH_KEY_PATH="$(echo "${secrets}" | jq -r '.key_path // empty')"
      log "Auth: mtls (certificate paths from Vault)"
      ;;
    *)
      log "ERROR: unknown auth_method '${auth_method}' in Vault (use jwt, keyring, or mtls)"
      return 1
      ;;
  esac

  # Optional: pre-generated provider JWT (AEP-64) or Console API key (AEP-63)
  local provider_jwt console_api_key
  provider_jwt="$(echo "${secrets}" | jq -r '.provider_jwt // empty')"
  console_api_key="$(echo "${secrets}" | jq -r '.console_api_key // empty')"
  if [[ -n "${provider_jwt}" && "${provider_jwt}" != "REPLACE_ME" ]]; then
    export AKASH_JWT="${provider_jwt}"
    log "Using pre-generated AKASH_JWT from Vault (short-lived — rotate regularly)"
  fi
  if [[ -n "${console_api_key}" && "${console_api_key}" != "REPLACE_ME" ]]; then
    export AKASH_CONSOLE_API_KEY="${console_api_key}"
    log "Console API key loaded from Vault (AEP-63)"
  fi

  export AKASH_AUTH_CONFIGURED=true
  log "Akash auth ready: address=${AKASH_ACCOUNT_ADDRESS} chain=${AKASH_CHAIN_ID}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  configure_akash_auth
fi

#!/usr/bin/env bash
# vault/setup/01-init.sh
#
# Initialize a fresh Vault cluster with Shamir 5/3 by default and write
# the unseal shares + root token to ${OUTPUT_DIR:-./.vault-init} as
# strict-mode 600 files. The caller is responsible for distributing the
# shares to the 5 holders (TEE / Yubikey / paper) IMMEDIATELY and then
# wiping the local copy.
#
# Idempotent: if Vault is already initialised it just unseals (if
# UNSEAL_KEYS_FILE is provided) and exits 0.
#
# Required env:
#   VAULT_ADDR
# Optional env:
#   KEY_SHARES        (default 5)
#   KEY_THRESHOLD     (default 3)
#   OUTPUT_DIR        (default ./.vault-init)
#   UNSEAL_KEYS_FILE  (path to existing JSON to unseal an already-init'd cluster)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib.sh"

KEY_SHARES="${KEY_SHARES:-5}"
KEY_THRESHOLD="${KEY_THRESHOLD:-3}"
OUTPUT_DIR="${OUTPUT_DIR:-./.vault-init}"

command -v vault >/dev/null || die "vault CLI not on PATH"
command -v jq    >/dev/null || die "jq not on PATH"

wait_for_vault

if is_initialized; then
  log "Vault already initialised."
else
  log "Initialising Vault (shares=${KEY_SHARES}, threshold=${KEY_THRESHOLD})"
  mkdir -p "${OUTPUT_DIR}"
  chmod 700 "${OUTPUT_DIR}"
  umask 077
  vault operator init \
    -key-shares="${KEY_SHARES}" \
    -key-threshold="${KEY_THRESHOLD}" \
    -format=json > "${OUTPUT_DIR}/init.json"
  chmod 600 "${OUTPUT_DIR}/init.json"
  warn "Init payload written to ${OUTPUT_DIR}/init.json"
  warn "DISTRIBUTE the ${KEY_SHARES} unseal shares to holders NOW, then shred this file."
fi

if is_sealed; then
  KEYS_FILE="${UNSEAL_KEYS_FILE:-${OUTPUT_DIR}/init.json}"
  [ -r "${KEYS_FILE}" ] || die "Vault is sealed and no keys file at ${KEYS_FILE}"
  log "Unsealing using ${KEYS_FILE}"
  for i in $(seq 0 $((KEY_THRESHOLD - 1))); do
    key="$(jq -r --argjson i "$i" '.unseal_keys_b64[$i]' "${KEYS_FILE}")"
    vault operator unseal "${key}" >/dev/null
  done
fi

# Export root token for downstream scripts that source this file.
if [ -z "${VAULT_TOKEN:-}" ] && [ -r "${OUTPUT_DIR}/init.json" ]; then
  export VAULT_TOKEN="$(jq -r '.root_token' "${OUTPUT_DIR}/init.json")"
  warn "VAULT_TOKEN exported from init.json. Revoke this root token after bootstrap completes."
fi

vault status
log "Init/unseal complete."

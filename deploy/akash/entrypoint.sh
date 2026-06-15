#!/usr/bin/env bash
set -euo pipefail

for required_bin in curl jq; do
  if ! command -v "${required_bin}" >/dev/null 2>&1; then
    echo "Missing dependency: ${required_bin}" >&2
    exit 1
  fi
done

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_KV_MOUNT:=kv-runtime}"
: "${VAULT_SECRET_PATH:=akash/runtime}"

fetch_vault_token() {
  if [[ -n "${VAULT_TOKEN:-}" ]]; then
    printf "%s" "${VAULT_TOKEN}"
    return
  fi

  : "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID when VAULT_TOKEN is not provided}"
  : "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID when VAULT_TOKEN is not provided}"

  local login_payload
  login_payload="$(jq -nc --arg role_id "${VAULT_ROLE_ID}" --arg secret_id "${VAULT_SECRET_ID}" '{role_id: $role_id, secret_id: $secret_id}')"

  curl --fail --silent --show-error --retry 3 --retry-delay 1 --connect-timeout 5 \
    --request POST \
    --data "${login_payload}" \
    "${VAULT_ADDR}/v1/auth/approle/login" | jq -r '.auth.client_token'
}

VAULT_RUNTIME_TOKEN="$(fetch_vault_token)"
if [[ -z "${VAULT_RUNTIME_TOKEN}" || "${VAULT_RUNTIME_TOKEN}" == "null" ]]; then
  echo "Failed to obtain Vault token" >&2
  exit 1
fi

secret_response="$(
  curl --fail --silent --show-error --retry 3 --retry-delay 1 --connect-timeout 5 \
    --header "X-Vault-Token: ${VAULT_RUNTIME_TOKEN}" \
    "${VAULT_ADDR}/v1/${VAULT_KV_MOUNT}/data/${VAULT_SECRET_PATH}"
)"

mapfile -t secret_keys < <(printf "%s" "${secret_response}" | jq -r '.data.data | keys[]')

for key in "${secret_keys[@]}"; do
  if [[ ! "${key}" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
    echo "Invalid secret key name for environment export: ${key}" >&2
    exit 1
  fi

  value="$(printf "%s" "${secret_response}" | jq -r --arg key "${key}" '.data.data[$key]')"
  export "${key}=${value}"
done

unset VAULT_RUNTIME_TOKEN VAULT_TOKEN VAULT_SECRET_ID VAULT_ROLE_ID secret_response

exec "$@"

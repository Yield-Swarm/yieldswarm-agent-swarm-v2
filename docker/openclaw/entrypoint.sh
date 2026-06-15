#!/bin/sh

set -eu

umask 077

TMP_VAULT_CACERT=""

cleanup() {
  if [ -n "${TMP_VAULT_CACERT}" ] && [ -f "${TMP_VAULT_CACERT}" ]; then
    rm -f "${TMP_VAULT_CACERT}"
  fi
}

trap cleanup EXIT INT TERM

require_env() {
  var_name="$1"
  eval "var_value=\${${var_name}:-}"
  if [ -z "${var_value}" ]; then
    echo "missing required environment variable: ${var_name}" >&2
    exit 1
  fi
}

json_post() {
  path="$1"
  token="$2"
  payload="${3:-}"

  set -- curl --fail --silent --show-error

  if [ "${VAULT_SKIP_VERIFY:-false}" = "true" ]; then
    set -- "$@" --insecure
  elif [ -n "${VAULT_CACERT:-}" ]; then
    set -- "$@" --cacert "${VAULT_CACERT}"
  fi

  if [ -n "${VAULT_NAMESPACE:-}" ]; then
    set -- "$@" --header "X-Vault-Namespace: ${VAULT_NAMESPACE}"
  fi

  if [ -n "${token}" ]; then
    set -- "$@" --header "X-Vault-Token: ${token}"
  fi

  if [ -n "${payload}" ]; then
    set -- "$@" --header "Content-Type: application/json" --data "${payload}"
  fi

  "$@" --request POST "${VAULT_ADDR}/v1/${path}"
}

json_get() {
  path="$1"
  token="$2"

  set -- curl --fail --silent --show-error

  if [ "${VAULT_SKIP_VERIFY:-false}" = "true" ]; then
    set -- "$@" --insecure
  elif [ -n "${VAULT_CACERT:-}" ]; then
    set -- "$@" --cacert "${VAULT_CACERT}"
  fi

  if [ -n "${VAULT_NAMESPACE:-}" ]; then
    set -- "$@" --header "X-Vault-Namespace: ${VAULT_NAMESPACE}"
  fi

  "$@" --header "X-Vault-Token: ${token}" "${VAULT_ADDR}/v1/${path}"
}

if [ -n "${VAULT_CACERT_B64:-}" ]; then
  TMP_VAULT_CACERT="$(mktemp)"
  printf '%s' "${VAULT_CACERT_B64}" | base64 -d > "${TMP_VAULT_CACERT}"
  VAULT_CACERT="${TMP_VAULT_CACERT}"
  export VAULT_CACERT
fi

require_env "VAULT_ADDR"
require_env "VAULT_ROLE_ID"
require_env "VAULT_WRAPPED_SECRET_ID"

VAULT_AUTH_PATH="${VAULT_AUTH_PATH:-approle}"
VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-kvv2}"
VAULT_SECRET_PATH="${VAULT_SECRET_PATH:-apps/openclaw/runtime}"
VAULT_SECRET_JSON_FILE="${VAULT_SECRET_JSON_FILE:-}"

unwrap_response="$(json_post "sys/wrapping/unwrap" "${VAULT_WRAPPED_SECRET_ID}")"
secret_id="$(printf '%s' "${unwrap_response}" | jq -er '.data.secret_id')"

login_payload="$(jq -cn \
  --arg role_id "${VAULT_ROLE_ID}" \
  --arg secret_id "${secret_id}" \
  '{role_id: $role_id, secret_id: $secret_id}')"
login_response="$(json_post "auth/${VAULT_AUTH_PATH}/login" "" "${login_payload}")"
vault_token="$(printf '%s' "${login_response}" | jq -er '.auth.client_token')"

unset secret_id
unset VAULT_WRAPPED_SECRET_ID

secret_response="$(json_get "${VAULT_KV_MOUNT}/data/${VAULT_SECRET_PATH}" "${vault_token}")"
secret_payload="$(printf '%s' "${secret_response}" | jq -ec '.data.data')"

if [ -n "${VAULT_SECRET_JSON_FILE}" ]; then
  printf '%s\n' "${secret_payload}" > "${VAULT_SECRET_JSON_FILE}"
  chmod 600 "${VAULT_SECRET_JSON_FILE}"
fi

secret_entries="$(printf '%s\n' "${secret_payload}" | jq -r 'to_entries[] | @base64')"
OLD_IFS="${IFS}"
IFS='
'
for entry in ${secret_entries}; do
  decoded="$(printf '%s' "${entry}" | base64 -d)"
  key="$(printf '%s' "${decoded}" | jq -er '.key')"
  value="$(printf '%s' "${decoded}" | jq -cer 'if .value == null then "" elif (.value | type) == "string" then .value else (.value | @json) end')"
  export "${key}=${value}"
done
IFS="${OLD_IFS}"

unset unwrap_response
unset login_payload
unset login_response
unset secret_response
unset secret_payload
unset secret_entries
unset vault_token

if [ "$#" -eq 0 ]; then
  set -- python3 -u /app/agents/openclaw-scaler.py
fi

exec "$@"

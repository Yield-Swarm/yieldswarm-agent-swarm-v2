#!/usr/bin/env bash
set -euo pipefail

umask 077

required_env_vars=(
  VAULT_ADDR
  VAULT_ROLE_ID
)

for env_var in "${required_env_vars[@]}"; do
  if [[ -z "${!env_var:-}" ]]; then
    printf 'Missing required environment variable: %s\n' "${env_var}" >&2
    exit 64
  fi
done

if [[ -n "${VAULT_SECRET_ID:-}" && -n "${VAULT_WRAPPED_SECRET_ID_TOKEN:-}" ]]; then
  printf 'Set either VAULT_SECRET_ID or VAULT_WRAPPED_SECRET_ID_TOKEN, not both.\n' >&2
  exit 64
fi

if [[ -z "${VAULT_SECRET_ID:-}" && -z "${VAULT_WRAPPED_SECRET_ID_TOKEN:-}" ]]; then
  printf 'Missing Vault bootstrap secret: provide VAULT_SECRET_ID or VAULT_WRAPPED_SECRET_ID_TOKEN.\n' >&2
  exit 64
fi

VAULT_AUTH_PATH="${VAULT_AUTH_PATH:-approle}"
VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-kv}"
VAULT_SECRET_PATH="${VAULT_SECRET_PATH:-runtime/akash}"
VAULT_ENV_FILE="${VAULT_ENV_FILE:-/run/secrets/runtime.env}"
VAULT_MAX_ATTEMPTS="${VAULT_MAX_ATTEMPTS:-5}"
VAULT_RETRY_BACKOFF_SECONDS="${VAULT_RETRY_BACKOFF_SECONDS:-2}"
VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-false}"

declare -a curl_tls_args=()
if [[ -n "${VAULT_CACERT_PATH:-}" ]]; then
  curl_tls_args+=(--cacert "${VAULT_CACERT_PATH}")
fi

if [[ "${VAULT_SKIP_VERIFY}" == "true" ]]; then
  curl_tls_args+=(--insecure)
fi

declare -a vault_headers=()
if [[ -n "${VAULT_NAMESPACE:-}" ]]; then
  vault_headers+=(--header "X-Vault-Namespace: ${VAULT_NAMESPACE}")
fi

vault_runtime_token=""
app_pid=""

cleanup() {
  local exit_code="$?"

  if [[ -n "${app_pid:-}" ]] && kill -0 "${app_pid}" >/dev/null 2>&1; then
    wait "${app_pid}" || true
  fi

  if [[ -n "${vault_runtime_token:-}" ]]; then
    vault_api "POST" "auth/token/revoke-self" "${vault_runtime_token}" "" >/dev/null 2>&1 || true
  fi

  unset VAULT_SECRET_ID VAULT_WRAPPED_SECRET_ID_TOKEN vault_runtime_token
  return "${exit_code}"
}

trap cleanup EXIT

forward_signal() {
  local signal="$1"

  if [[ -n "${app_pid:-}" ]] && kill -0 "${app_pid}" >/dev/null 2>&1; then
    kill "-${signal}" "${app_pid}" >/dev/null 2>&1 || kill -s "${signal}" "${app_pid}" >/dev/null 2>&1 || true
  fi
}

trap 'forward_signal TERM' TERM
trap 'forward_signal INT' INT
trap 'forward_signal HUP' HUP

vault_api() {
  local method="$1"
  local endpoint="$2"
  local token="${3:-}"
  local body="${4:-}"
  local -a args=(
    --silent
    --show-error
    --fail
    "${curl_tls_args[@]}"
    --request "${method}"
  )

  if [[ "${#vault_headers[@]}" -gt 0 ]]; then
    args+=("${vault_headers[@]}")
  fi

  if [[ -n "${token}" ]]; then
    args+=(--header "X-Vault-Token: ${token}")
  fi

  if [[ -n "${body}" ]]; then
    args+=(--header "Content-Type: application/json" --data "${body}")
  fi

  args+=("${VAULT_ADDR%/}/v1/${endpoint}")

  curl "${args[@]}"
}

vault_api_with_retry() {
  local method="$1"
  local endpoint="$2"
  local token="${3:-}"
  local body="${4:-}"
  local attempt=1
  local sleep_seconds="${VAULT_RETRY_BACKOFF_SECONDS}"
  local response

  while true; do
    if response="$(vault_api "${method}" "${endpoint}" "${token}" "${body}" 2>&1)"; then
      printf '%s' "${response}"
      return 0
    fi

    if (( attempt >= VAULT_MAX_ATTEMPTS )); then
      printf 'Vault API call to %s failed after %s attempts: %s\n' "${endpoint}" "${attempt}" "${response}" >&2
      return 1
    fi

    printf 'Vault API call to %s failed on attempt %s/%s; retrying in %ss.\n' \
      "${endpoint}" "${attempt}" "${VAULT_MAX_ATTEMPTS}" "${sleep_seconds}" >&2
    sleep "${sleep_seconds}"
    attempt=$((attempt + 1))
    sleep_seconds=$((sleep_seconds * 2))
  done
}

unwrap_secret_id() {
  local unwrap_response

  unwrap_response="$(vault_api_with_retry "POST" "sys/wrapping/unwrap" "${VAULT_WRAPPED_SECRET_ID_TOKEN}" "")"
  printf '%s' "${unwrap_response}" | jq -er '.data.secret_id'
}

vault_secret_id="${VAULT_SECRET_ID:-}"
if [[ -n "${VAULT_WRAPPED_SECRET_ID_TOKEN:-}" ]]; then
  vault_secret_id="$(unwrap_secret_id)"
  unset VAULT_WRAPPED_SECRET_ID_TOKEN
fi

login_payload="$(jq -cn \
  --arg role_id "${VAULT_ROLE_ID}" \
  --arg secret_id "${vault_secret_id}" \
  '{role_id: $role_id, secret_id: $secret_id}')"

auth_response="$(vault_api_with_retry "POST" "auth/${VAULT_AUTH_PATH}/login" "" "${login_payload}")"
vault_runtime_token="$(printf '%s' "${auth_response}" | jq -er '.auth.client_token')"

unset vault_secret_id VAULT_SECRET_ID

secret_response="$(vault_api_with_retry "GET" "${VAULT_KV_MOUNT}/data/${VAULT_SECRET_PATH}" "${vault_runtime_token}" "")"

invalid_keys="$(printf '%s' "${secret_response}" | jq -r '
  .data.data
  | keys[]
  | select(test("^[A-Za-z_][A-Za-z0-9_]*$") | not)
')"

if [[ -n "${invalid_keys}" ]]; then
  printf 'Vault secret %s/data/%s contains invalid environment variable keys:\n%s\n' \
    "${VAULT_KV_MOUNT}" "${VAULT_SECRET_PATH}" "${invalid_keys}" >&2
  exit 65
fi

mkdir -p "$(dirname "${VAULT_ENV_FILE}")"
tmp_env_file="$(mktemp "${TMPDIR:-/tmp}/vault-env.XXXXXX")"

printf '%s' "${secret_response}" | jq -er '
  .data.data
  | to_entries
  | if length == 0 then error("Vault secret payload is empty") else . end
  | .[]
  | "export \(.key)=\(((if (.value | type) == "string" then .value else (.value | tojson) end) | @sh))"
' > "${tmp_env_file}"

chmod 600 "${tmp_env_file}"
mv "${tmp_env_file}" "${VAULT_ENV_FILE}"
chmod 600 "${VAULT_ENV_FILE}"

set -a
# shellcheck disable=SC1090
source "${VAULT_ENV_FILE}"
set +a

printf 'Vault runtime secrets loaded from %s/data/%s.\n' "${VAULT_KV_MOUNT}" "${VAULT_SECRET_PATH}" >&2

if [[ "$#" -gt 0 ]]; then
  "$@" &
  app_pid="$!"
  wait "${app_pid}"
  exit "$?"
fi

if [[ -n "${APP_CMD:-}" ]]; then
  bash -lc "${APP_CMD}" &
  app_pid="$!"
  wait "${app_pid}"
  exit "$?"
fi

printf 'No application command supplied. Pass command arguments or set APP_CMD.\n' >&2
exit 64

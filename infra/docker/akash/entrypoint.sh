#!/usr/bin/env sh
set -eu

umask 077

log() {
  printf '%s\n' "$*" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing required command: $1"
    exit 1
  fi
}

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    log "missing required environment variable: $name"
    exit 1
  fi
}

read_value_or_file() {
  value_name="$1"
  file_name="$2"

  eval "value=\${$value_name:-}"
  eval "file_path=\${$file_name:-}"

  if [ -n "$value" ] && [ -n "$file_path" ]; then
    log "set either $value_name or $file_name, not both"
    exit 1
  fi

  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi

  if [ -n "$file_path" ]; then
    if [ ! -f "$file_path" ]; then
      log "file referenced by $file_name does not exist: $file_path"
      exit 1
    fi

    tr -d '\n' < "$file_path"
    return 0
  fi

  return 1
}

curl_json() {
  request_token="$1"
  method="$2"
  path="$3"
  payload="${4:-}"

  set -- \
    -fsS \
    --retry 3 \
    --retry-delay 1 \
    --retry-connrefused \
    -X "$method" \
    -H "Content-Type: application/json"

  if [ -n "${VAULT_NAMESPACE:-}" ]; then
    set -- "$@" -H "X-Vault-Namespace: ${VAULT_NAMESPACE}"
  fi

  if [ -n "$request_token" ]; then
    set -- "$@" -H "X-Vault-Token: ${request_token}"
  fi

  if [ -n "${VAULT_CACERT:-}" ]; then
    set -- "$@" --cacert "${VAULT_CACERT}"
  fi

  if [ -n "${VAULT_CURL_EXTRA_ARGS:-}" ]; then
    # shellcheck disable=SC2086
    set -- "$@" ${VAULT_CURL_EXTRA_ARGS}
  fi

  if [ -n "$payload" ]; then
    set -- "$@" --data "$payload"
  fi

  curl "$@" "${VAULT_ADDR%/}/v1/${path}"
}

render_env_file() {
  env_json="$1"
  output_file="$2"
  output_dir=$(dirname "$output_file")
  tmp_file="${output_file}.tmp.$$"

  mkdir -p "$output_dir"

  printf '%s' "$env_json" | jq -r '
    to_entries[]
    | select(.key | test("^[A-Za-z_][A-Za-z0-9_]*$"))
    | "\(.key)=\(.value | @sh)"
  ' > "$tmp_file"

  mv "$tmp_file" "$output_file"
}

assert_required_secret_keys() {
  env_json="$1"

  if [ -z "${VAULT_REQUIRED_SECRET_KEYS:-}" ]; then
    return 0
  fi

  OLD_IFS=$IFS
  IFS=','
  # shellcheck disable=SC2086
  set -- ${VAULT_REQUIRED_SECRET_KEYS}
  IFS=$OLD_IFS

  for raw_key in "$@"; do
    key=$(printf '%s' "$raw_key" | sed 's/^ *//; s/ *$//')
    if [ -z "$key" ]; then
      continue
    fi

    if ! printf '%s' "$env_json" | jq -e --arg key "$key" 'has($key)' >/dev/null; then
      log "Vault secret is missing required key: $key"
      exit 1
    fi
  done
}

revoke_self_token() {
  login_token="$1"

  if [ -z "$login_token" ]; then
    return 0
  fi

  if [ "${VAULT_REVOKE_TOKEN_AFTER_RENDER:-true}" != "true" ]; then
    return 0
  fi

  if ! curl_json "$login_token" "POST" "auth/token/revoke-self" "" >/dev/null 2>&1; then
    log "warning: unable to revoke Vault token after rendering secrets"
  fi
}

start_command() {
  if [ "$#" -gt 0 ]; then
    exec "$@"
  elif [ -n "${APP_START_COMMAND:-}" ]; then
    exec /bin/sh -c "${APP_START_COMMAND}"
  else
    log "no application command provided; set APP_START_COMMAND or pass a command"
    exit 1
  fi
}

require_command curl
require_command jq
require_command sed
require_env VAULT_ADDR
require_env VAULT_SECRET_PATH

VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-apps}"
VAULT_ENV_FILE="${VAULT_ENV_FILE:-/tmp/agentswarm-runtime.env}"

login_token=""
token_source="external"

if login_token="$(read_value_or_file "VAULT_TOKEN" "VAULT_TOKEN_FILE")"; then
  :
else
  require_env VAULT_APPROLE_ROLE_ID

  if ! wrapped_secret_id="$(read_value_or_file "VAULT_WRAPPED_SECRET_ID" "VAULT_WRAPPED_SECRET_ID_FILE")"; then
    log "set VAULT_TOKEN/VAULT_TOKEN_FILE or provide a wrapped AppRole SecretID"
    exit 1
  fi

  unwrap_response="$(curl_json "$wrapped_secret_id" "POST" "sys/wrapping/unwrap" "")"
  secret_id="$(printf '%s' "$unwrap_response" | jq -er '.data.secret_id')"

  login_payload="$(jq -nc \
    --arg role_id "${VAULT_APPROLE_ROLE_ID}" \
    --arg secret_id "$secret_id" \
    '{role_id: $role_id, secret_id: $secret_id}')"

  login_response="$(curl_json "" "POST" "auth/approle/login" "$login_payload")"
  login_token="$(printf '%s' "$login_response" | jq -er '.auth.client_token')"
  token_source="approle"

  unset wrapped_secret_id secret_id unwrap_response login_payload login_response
fi

secret_response="$(curl_json "$login_token" "GET" "${VAULT_KV_MOUNT}/data/${VAULT_SECRET_PATH}" "")"
env_json="$(printf '%s' "$secret_response" | jq -cer '.data.data')"

assert_required_secret_keys "$env_json"
render_env_file "$env_json" "$VAULT_ENV_FILE"

set -a
. "$VAULT_ENV_FILE"
set +a

if [ "$token_source" = "approle" ]; then
  revoke_self_token "$login_token"
fi

unset login_token secret_response env_json token_source

start_command "$@"

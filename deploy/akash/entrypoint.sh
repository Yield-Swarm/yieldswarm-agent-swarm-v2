#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[akash-entrypoint] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

read_secret_input() {
  local env_name="$1"
  local file_env_name="${env_name}_FILE"
  local file_path="${!file_env_name:-}"

  if [[ -n "$file_path" ]]; then
    [[ -r "$file_path" ]] || die "$file_env_name points to an unreadable file"
    tr -d '\r\n' < "$file_path"
    return
  fi

  printf '%s' "${!env_name:-}"
}

vault_url() {
  local path="${1#/}"
  printf '%s/v1/%s' "${VAULT_ADDR%/}" "$path"
}

curl_common_args() {
  local -a args
  args=(-fsS --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30)

  if [[ -n "${VAULT_NAMESPACE:-}" ]]; then
    args+=(-H "X-Vault-Namespace: ${VAULT_NAMESPACE}")
  fi

  printf '%s\0' "${args[@]}"
}

vault_post_without_client_token() {
  local path="$1"
  shift

  local -a common
  mapfile -d '' -t common < <(curl_common_args)
  curl "${common[@]}" -X POST "$@" "$(vault_url "$path")"
}

vault_get() {
  local path="$1"
  local -a common
  mapfile -d '' -t common < <(curl_common_args)
  curl "${common[@]}" -H "X-Vault-Token: ${VAULT_TOKEN}" "$(vault_url "$path")"
}

vault_unwrap() {
  local wrapping_token="$1"
  [[ -n "$wrapping_token" ]] || die "cannot unwrap an empty Vault wrapping token"

  vault_post_without_client_token \
    "sys/wrapping/unwrap" \
    -H "X-Vault-Token: ${wrapping_token}"
}

vault_login_approle() {
  local role_id="$1"
  local secret_id="$2"
  [[ -n "$role_id" ]] || die "VAULT_ROLE_ID or VAULT_ROLE_ID_FILE is required for AppRole auth"
  [[ -n "$secret_id" ]] || die "VAULT_SECRET_ID, VAULT_SECRET_ID_FILE, or VAULT_WRAPPED_SECRET_ID is required for AppRole auth"

  local payload
  payload="$(jq -n --arg role_id "$role_id" --arg secret_id "$secret_id" '{role_id: $role_id, secret_id: $secret_id}')"

  vault_post_without_client_token \
    "auth/approle/login" \
    -H "Content-Type: application/json" \
    --data "$payload" |
    jq -er '.auth.client_token'
}

resolve_vault_token() {
  local token
  token="$(read_secret_input "VAULT_TOKEN")"
  if [[ -n "$token" ]]; then
    printf '%s' "$token"
    return
  fi

  local wrapped_client_token
  wrapped_client_token="$(read_secret_input "VAULT_WRAPPED_TOKEN")"
  if [[ -n "$wrapped_client_token" ]]; then
    vault_unwrap "$wrapped_client_token" | jq -er '.auth.client_token // .data.token'
    return
  fi

  local role_id secret_id wrapped_secret_id
  role_id="$(read_secret_input "VAULT_ROLE_ID")"
  secret_id="$(read_secret_input "VAULT_SECRET_ID")"
  wrapped_secret_id="$(read_secret_input "VAULT_WRAPPED_SECRET_ID")"

  if [[ -n "$wrapped_secret_id" ]]; then
    secret_id="$(vault_unwrap "$wrapped_secret_id" | jq -er '.data.secret_id')"
  fi

  if [[ -n "$role_id" || -n "$secret_id" ]]; then
    vault_login_approle "$role_id" "$secret_id"
    return
  fi

  die "no Vault auth material found; set VAULT_TOKEN_FILE, VAULT_WRAPPED_TOKEN_FILE, or AppRole inputs"
}

export_kv2_secret() {
  local logical_path="${1#/}"
  local api_path="${VAULT_KV_MOUNT:-secret}/data/${logical_path}"
  local response entries_loaded

  response="$(vault_get "$api_path")"
  printf '%s' "$response" | jq -e '.data.data | type == "object"' >/dev/null

  entries_loaded=0
  while IFS= read -r encoded_entry; do
    local entry key value
    entry="$(printf '%s' "$encoded_entry" | base64 -d)"
    key="$(printf '%s' "$entry" | jq -r '.key')"
    value="$(printf '%s' "$entry" | jq -r '.value | if type == "string" then . else @json end')"

    if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "${key}=${value}"
      entries_loaded=$((entries_loaded + 1))
    else
      die "Vault key '${key}' from '${logical_path}' is not a valid environment variable name"
    fi
  done < <(printf '%s' "$response" | jq -r '.data.data | to_entries[] | @base64')

  log "loaded ${entries_loaded} environment values from Vault path '${logical_path}'"
}

validate_required_env() {
  local required_csv="${REQUIRED_RUNTIME_ENV:-}"
  [[ -n "$required_csv" ]] || return 0

  local missing=()
  IFS=',' read -ra required_names <<< "$required_csv"
  for name in "${required_names[@]}"; do
    name="${name//[[:space:]]/}"
    [[ -z "$name" ]] && continue
    if [[ -z "${!name:-}" ]]; then
      missing+=("$name")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    die "required runtime environment values were not loaded: ${missing[*]}"
  fi
}

main() {
  [[ -n "${VAULT_ADDR:-}" ]] || die "VAULT_ADDR is required"
  command -v curl >/dev/null || die "curl is required"
  command -v jq >/dev/null || die "jq is required"
  command -v base64 >/dev/null || die "base64 is required"

  VAULT_TOKEN="$(resolve_vault_token)"
  export VAULT_TOKEN

  export_kv2_secret "${VAULT_AKASH_SECRET_PATH:-runtime/akash}"
  export_kv2_secret "${VAULT_RPC_SECRET_PATH:-terraform/rpc}"

  if [[ -n "${VAULT_EXTRA_SECRET_PATHS:-}" ]]; then
    IFS=',' read -ra extra_paths <<< "$VAULT_EXTRA_SECRET_PATHS"
    for path in "${extra_paths[@]}"; do
      path="${path//[[:space:]]/}"
      [[ -n "$path" ]] && export_kv2_secret "$path"
    done
  fi

  validate_required_env

  unset VAULT_TOKEN VAULT_SECRET_ID VAULT_WRAPPED_SECRET_ID VAULT_WRAPPED_TOKEN
  log "starting workload command"
  exec "$@"
}

main "$@"

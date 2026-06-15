#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

log() {
  printf '[akash-entrypoint] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

read_secret_source() {
  local env_name="$1"
  local file_env_name="$2"
  local value=""
  local file_path=""

  if [[ -n "${!env_name:-}" ]]; then
    value="${!env_name}"
  elif [[ -n "${!file_env_name:-}" ]]; then
    file_path="${!file_env_name}"
    [[ -r "$file_path" ]] || die "$file_env_name points to an unreadable file"
    value="$(<"$file_path")"
  fi

  printf '%s' "$value"
}

unwrap_bootstrap_token() {
  local wrap_token="$1"
  local payload=""
  local token=""
  local secret_id=""

  payload="$(VAULT_TOKEN= vault unwrap -format=json "$wrap_token")" || die "failed to unwrap Vault bootstrap token"
  token="$(jq -r '.auth.client_token // .data.token // empty' <<<"$payload")"
  secret_id="$(jq -r '.data.secret_id // empty' <<<"$payload")"

  if [[ -n "$token" ]]; then
    export VAULT_TOKEN="$token"
    return 0
  fi

  if [[ -n "$secret_id" ]]; then
    export VAULT_SECRET_ID_UNWRAPPED="$secret_id"
    return 0
  fi

  die "wrapped Vault bootstrap token did not contain a token or AppRole secret_id"
}

authenticate_vault() {
  local token=""
  local wrap_token=""
  local role_id=""
  local secret_id=""
  local approle_mount="${VAULT_APPROLE_MOUNT:-approle}"

  token="$(read_secret_source VAULT_TOKEN VAULT_TOKEN_FILE)"
  if [[ -n "$token" ]]; then
    export VAULT_TOKEN="$token"
    return 0
  fi

  wrap_token="$(read_secret_source VAULT_WRAP_TOKEN VAULT_WRAP_TOKEN_FILE)"
  if [[ -n "$wrap_token" ]]; then
    unwrap_bootstrap_token "$wrap_token"
    if [[ -n "${VAULT_TOKEN:-}" ]]; then
      return 0
    fi
  fi

  role_id="$(read_secret_source VAULT_ROLE_ID VAULT_ROLE_ID_FILE)"
  secret_id="${VAULT_SECRET_ID_UNWRAPPED:-$(read_secret_source VAULT_SECRET_ID VAULT_SECRET_ID_FILE)}"

  [[ -n "$role_id" ]] || die "VAULT_ROLE_ID or VAULT_ROLE_ID_FILE is required when VAULT_TOKEN is not provided"
  [[ -n "$secret_id" ]] || die "VAULT_SECRET_ID, VAULT_SECRET_ID_FILE, or a wrapped secret_id is required"

  export VAULT_TOKEN="$(
    vault write -field=token "auth/${approle_mount}/login" \
      role_id="$role_id" \
      secret_id="$secret_id"
  )" || die "Vault AppRole login failed"
}

render_exports_for_secret_path() {
  local path="$1"
  local mount="${VAULT_KV_MOUNT:-secret}"
  local payload=""
  local invalid_keys=""

  payload="$(vault kv get -format=json -mount="$mount" "$path")" || die "failed to read Vault secret path: ${mount}/${path}"

  invalid_keys="$(
    jq -r '
      .data.data
      | keys[]
      | select(test("^[A-Za-z_][A-Za-z0-9_]*$") | not)
    ' <<<"$payload"
  )"
  [[ -z "$invalid_keys" ]] || die "Vault secret ${mount}/${path} contains keys that are not valid environment variable names"

  jq -r '
    .data.data
    | to_entries[]
    | "export " + .key + "=" + ((.value | if type == "string" then . else tojson end) | @sh)
  ' <<<"$payload"
}

load_runtime_environment() {
  local secret_paths="${VAULT_SECRET_PATHS:-akash/runtime,rpc}"
  local env_file=""
  local raw_path=""
  local path=""

  env_file="$(mktemp /run/yieldswarm-env.XXXXXX 2>/dev/null || mktemp)"
  export AKASH_RUNTIME_ENV_FILE="$env_file"

  IFS=',' read -r -a paths <<<"$secret_paths"
  [[ "${#paths[@]}" -gt 0 ]] || die "VAULT_SECRET_PATHS did not include any paths"

  for raw_path in "${paths[@]}"; do
    path="${raw_path//[[:space:]]/}"
    [[ -n "$path" ]] || continue
    render_exports_for_secret_path "$path" >>"$env_file"
  done

  # shellcheck disable=SC1090
  source "$env_file"
}

cleanup() {
  local exit_code="$?"

  if [[ -n "${AKASH_RUNTIME_ENV_FILE:-}" ]]; then
    rm -f "$AKASH_RUNTIME_ENV_FILE"
  fi

  exit "$exit_code"
}

drop_vault_bootstrap_material() {
  if [[ "${VAULT_REVOKE_TOKEN_AFTER_LOAD:-true}" == "true" && "${VAULT_EXPORT_TOKEN_TO_CHILD:-false}" != "true" && -n "${VAULT_TOKEN:-}" ]]; then
    vault token revoke -self >/dev/null 2>&1 || log "warning: failed to revoke Vault token after loading secrets"
  fi

  if [[ "${VAULT_EXPORT_TOKEN_TO_CHILD:-false}" != "true" ]]; then
    unset VAULT_TOKEN
  fi

  unset VAULT_SECRET_ID VAULT_SECRET_ID_UNWRAPPED VAULT_WRAP_TOKEN
}

main() {
  require_cmd vault
  require_cmd jq

  [[ -n "${VAULT_ADDR:-}" ]] || die "VAULT_ADDR is required"

  trap cleanup EXIT

  authenticate_vault
  vault token lookup >/dev/null || die "Vault token lookup failed"
  load_runtime_environment
  rm -f "$AKASH_RUNTIME_ENV_FILE"
  unset AKASH_RUNTIME_ENV_FILE
  drop_vault_bootstrap_material

  log "runtime environment loaded from Vault"

  if [[ "$#" -eq 0 ]]; then
    [[ -n "${AGENT_COMMAND:-}" ]] || die "no command provided and AGENT_COMMAND is empty"
    exec bash -lc "$AGENT_COMMAND"
  fi

  exec "$@"
}

main "$@"

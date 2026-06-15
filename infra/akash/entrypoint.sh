#!/usr/bin/env bash
set -euo pipefail

require_bin() {
  local binary="$1"
  if ! command -v "${binary}" >/dev/null 2>&1; then
    echo "Missing required binary: ${binary}" >&2
    exit 1
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

value_from_env_or_file() {
  local name="$1"
  local value="${!name:-}"
  local file_var="${name}_FILE"
  local file_path="${!file_var:-}"

  if [[ -n "${value}" && -n "${file_path}" ]]; then
    echo "Both ${name} and ${file_var} are set; use only one." >&2
    exit 1
  fi

  if [[ -n "${file_path}" ]]; then
    if [[ ! -r "${file_path}" ]]; then
      echo "Unable to read ${file_var} path: ${file_path}" >&2
      exit 1
    fi
    value="$(<"${file_path}")"
  fi

  printf '%s' "${value}"
}

vault_request() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local url="${VAULT_ADDR%/}/v1/${endpoint}"

  local headers=()
  headers+=(-H "Content-Type: application/json")
  if [[ -n "${VAULT_NAMESPACE}" ]]; then
    headers+=(-H "X-Vault-Namespace: ${VAULT_NAMESPACE}")
  fi
  if [[ -n "${VAULT_TOKEN:-}" ]]; then
    headers+=(-H "X-Vault-Token: ${VAULT_TOKEN}")
  fi

  if [[ -n "${data}" ]]; then
    curl --silent --show-error --fail --request "${method}" "${headers[@]}" --data "${data}" "${url}"
  else
    curl --silent --show-error --fail --request "${method}" "${headers[@]}" "${url}"
  fi
}

authenticate() {
  local existing_token
  existing_token="$(value_from_env_or_file "VAULT_TOKEN")"
  if [[ -n "${existing_token}" ]]; then
    VAULT_TOKEN="${existing_token}"
    export VAULT_TOKEN
    return
  fi

  local auth_method
  auth_method="$(trim "${VAULT_AUTH_METHOD:-approle}")"
  if [[ "${auth_method}" != "approle" ]]; then
    echo "Unsupported VAULT_AUTH_METHOD: ${auth_method}. Only approle is supported." >&2
    exit 1
  fi

  local role_id
  local secret_id
  role_id="$(value_from_env_or_file "VAULT_ROLE_ID")"
  secret_id="$(value_from_env_or_file "VAULT_SECRET_ID")"

  if [[ -z "${role_id}" || -z "${secret_id}" ]]; then
    echo "VAULT_ROLE_ID and VAULT_SECRET_ID (or *_FILE variants) are required for AppRole auth." >&2
    exit 1
  fi

  local payload
  payload="$(jq -cn --arg role_id "${role_id}" --arg secret_id "${secret_id}" '{role_id: $role_id, secret_id: $secret_id}')"
  local login_json
  login_json="$(vault_request "POST" "auth/approle/login" "${payload}")"
  VAULT_TOKEN="$(jq -er '.auth.client_token' <<<"${login_json}")"
  export VAULT_TOKEN
}

load_kv_v2_secret() {
  local path="$1"
  local prefix="$2"

  local secret_json
  secret_json="$(vault_request "GET" "${path}")"

  local keys
  keys="$(jq -r '.data.data | keys[]' <<<"${secret_json}")"
  if [[ -z "${keys}" ]]; then
    echo "No keys found at Vault path: ${path}" >&2
    exit 1
  fi

  while IFS= read -r key; do
    [[ -z "${key}" ]] && continue
    local exported_key="${prefix}${key}"

    if [[ ! "${exported_key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Invalid environment variable name derived from Vault key: ${exported_key}" >&2
      exit 1
    fi

    local value
    value="$(jq -er --arg k "${key}" '.data.data[$k]' <<<"${secret_json}")"
    export "${exported_key}=${value}"
  done <<<"${keys}"
}

load_all_paths() {
  local mapping_list
  mapping_list="${VAULT_SECRET_PATHS:-app/data/akash,rpc/data/default}"

  IFS=',' read -r -a mappings <<<"${mapping_list}"
  for raw_mapping in "${mappings[@]}"; do
    local mapping
    mapping="$(trim "${raw_mapping}")"
    [[ -z "${mapping}" ]] && continue

    local path="${mapping%%|*}"
    local prefix=""
    if [[ "${mapping}" == *"|"* ]]; then
      prefix="${mapping#*|}"
    fi
    prefix="$(trim "${prefix}")"
    path="$(trim "${path}")"

    if [[ -z "${path}" ]]; then
      echo "Invalid entry in VAULT_SECRET_PATHS: ${raw_mapping}" >&2
      exit 1
    fi

    load_kv_v2_secret "${path}" "${prefix}"
  done
}

main() {
  if [[ "$#" -eq 0 ]]; then
    echo "Usage: entrypoint.sh <command> [args...]" >&2
    exit 1
  fi

  : "${VAULT_ADDR:?VAULT_ADDR is required.}"
  VAULT_NAMESPACE="${VAULT_NAMESPACE:-}"

  require_bin curl
  require_bin jq

  authenticate
  load_all_paths

  if [[ "${VAULT_KEEP_TOKEN:-false}" != "true" ]]; then
    unset VAULT_TOKEN
  fi

  exec "$@"
}

main "$@"

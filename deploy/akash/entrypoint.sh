#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[vault-entrypoint] %s\n' "$*" >&2
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_binary() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required binary: $1"
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "required environment variable $name is not set"
}

vault_api() {
  local method="$1"
  local path="$2"
  local token="$3"
  local body="${4:-}"
  local -a args

  args=(-fsS -X "$method" -H "X-Vault-Token: $token")
  if [[ -n "${VAULT_NAMESPACE:-}" ]]; then
    args+=(-H "X-Vault-Namespace: ${VAULT_NAMESPACE}")
  fi
  if [[ -n "$body" ]]; then
    args+=(-H "Content-Type: application/json" --data "$body")
  fi

  curl "${args[@]}" "${VAULT_ADDR%/}/v1/${path#/}"
}

unwrap_secret_id() {
  require_env VAULT_WRAPPED_SECRET_ID

  local response
  response="$(vault_api POST "sys/wrapping/unwrap" "$VAULT_WRAPPED_SECRET_ID")" ||
    fail "failed to unwrap AppRole secret ID"

  jq -er '.data.secret_id' <<<"$response" ||
    fail "wrapped Vault response did not contain data.secret_id"
}

login_approle() {
  require_env VAULT_ROLE_ID

  local secret_id="${VAULT_SECRET_ID:-}"
  if [[ -z "$secret_id" ]]; then
    secret_id="$(unwrap_secret_id)"
  fi

  local payload response
  payload="$(jq -n --arg role_id "$VAULT_ROLE_ID" --arg secret_id "$secret_id" \
    '{role_id: $role_id, secret_id: $secret_id}')"

  response="$(vault_api POST "auth/${VAULT_AUTH_PATH}/login" "" "$payload")" ||
    fail "failed to authenticate to Vault with AppRole"

  jq -er '.auth.client_token' <<<"$response" ||
    fail "Vault AppRole login response did not contain auth.client_token"
}

fetch_secret() {
  local secret_path="$1"
  local response

  response="$(vault_api GET "${VAULT_KV_MOUNT}/data/${secret_path}" "$VAULT_TOKEN")" ||
    fail "failed to read Vault secret path ${VAULT_KV_MOUNT}/${secret_path}"

  jq -er '.data.data' <<<"$response" ||
    fail "Vault secret ${VAULT_KV_MOUNT}/${secret_path} did not contain KV v2 data"
}

export_secret_field() {
  local env_name="$1"
  local field_name="$2"
  local secret_json="$3"
  local required="${4:-required}"
  local value

  [[ "$env_name" =~ ^[A-Z_][A-Z0-9_]*$ ]] || fail "invalid environment variable name: $env_name"

  value="$(jq -er --arg key "$field_name" '.[$key] // empty' <<<"$secret_json" 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    if [[ "$required" == "required" ]]; then
      fail "required field '$field_name' is missing from Vault secret"
    fi
    return 0
  fi

  printf -v "$env_name" '%s' "$value"
  export "$env_name"
}

inject_secret_path() {
  local secret_path="$1"
  local secret_json

  secret_json="$(fetch_secret "$secret_path")"

  case "$secret_path" in
    cloud/azure)
      export_secret_field AZURE_SUBSCRIPTION_ID subscription_id "$secret_json"
      export_secret_field AZURE_TENANT_ID tenant_id "$secret_json"
      export_secret_field AZURE_CLIENT_ID client_id "$secret_json"
      export_secret_field AZURE_CLIENT_SECRET client_secret "$secret_json"
      ;;
    cloud/runpod)
      export_secret_field RUNPOD_API_KEY api_key "$secret_json"
      ;;
    cloud/vultr)
      export_secret_field VULTR_API_KEY api_key "$secret_json"
      ;;
    cloud/digitalocean)
      export_secret_field DIGITALOCEAN_TOKEN token "$secret_json"
      export_secret_field DO_TOKEN token "$secret_json"
      ;;
    rpc)
      export_secret_field SOLANA_RPC_URL solana_rpc_url "$secret_json"
      export_secret_field FAILOVER_RPC_LIST failover_rpc_list_json "$secret_json"
      export_secret_field HELIUS_API_KEY helius_api_key "$secret_json" optional
      export_secret_field ETHEREUM_RPC_URL ethereum_rpc_url "$secret_json" optional
      export_secret_field BASE_RPC_URL base_rpc_url "$secret_json" optional
      export_secret_field POLYGON_RPC_URL polygon_rpc_url "$secret_json" optional
      ;;
    *)
      fail "unsupported Vault secret path '$secret_path'"
      ;;
  esac

  log "injected fields from ${VAULT_KV_MOUNT}/${secret_path}"
}

main() {
  require_binary curl
  require_binary jq
  require_binary bash
  require_env VAULT_ADDR

  : "${VAULT_AUTH_PATH:=approle}"
  : "${VAULT_KV_MOUNT:=yieldswarm}"
  : "${VAULT_SECRET_PATHS:=cloud/azure,cloud/runpod,cloud/vultr,cloud/digitalocean,rpc}"

  if [[ -z "${VAULT_TOKEN:-}" ]]; then
    VAULT_TOKEN="$(login_approle)"
    export VAULT_TOKEN
  fi

  local -a paths
  local raw_path secret_path
  IFS=',' read -r -a paths <<<"$VAULT_SECRET_PATHS"

  for raw_path in "${paths[@]}"; do
    secret_path="${raw_path#"${raw_path%%[![:space:]]*}"}"
    secret_path="${secret_path%"${secret_path##*[![:space:]]}"}"
    [[ -n "$secret_path" ]] || continue
    inject_secret_path "$secret_path"
  done

  unset VAULT_TOKEN VAULT_SECRET_ID VAULT_WRAPPED_SECRET_ID

  log "Vault secret injection complete; starting application"
  exec "$@"
}

main "$@"

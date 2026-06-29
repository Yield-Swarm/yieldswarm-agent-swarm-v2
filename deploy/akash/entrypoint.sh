#!/usr/bin/env bash
# Runtime secret injection for Akash deployments.
# Authenticates to Vault via AppRole, fetches secrets, exports env vars, then execs the workload.
# No secrets are baked into the image — only VAULT_ADDR, VAULT_ROLE_ID, and VAULT_SECRET_ID
# are supplied at deploy time via Akash SDL environment variables.

set -euo pipefail

VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-yieldswarm}"
VAULT_SECRET_PATHS="${VAULT_SECRET_PATHS:-runtime/akash,runtime/core,runtime/llm,rpc/solana}"
SECRETS_FILE="${SECRETS_FILE:-/run/secrets/app.env}"
VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-false}"

log() { printf '[entrypoint] %s\n' "$*" >&2; }

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    log "ERROR: ${name} is required but not set"
    exit 1
  fi
}

vault_login() {
  local payload
  payload="$(jq -n \
    --arg role_id "${VAULT_ROLE_ID}" \
    --arg secret_id "${VAULT_SECRET_ID}" \
    '{role_id: $role_id, secret_id: $secret_id}')"

  local curl_opts=(-sS --fail)
  if [[ "${VAULT_SKIP_VERIFY}" == "true" ]]; then
    curl_opts+=(-k)
  fi

  VAULT_TOKEN="$(
    curl "${curl_opts[@]}" \
      --request POST \
      --header "Content-Type: application/json" \
      --data "${payload}" \
      "${VAULT_ADDR}/v1/auth/approle/login" \
      | jq -r '.auth.client_token'
  )"

  if [[ -z "${VAULT_TOKEN}" || "${VAULT_TOKEN}" == "null" ]]; then
    log "ERROR: Vault AppRole login failed"
    exit 1
  fi
  export VAULT_TOKEN
}

fetch_kv_path() {
  local path="$1"
  local curl_opts=(-sS --fail)
  if [[ "${VAULT_SKIP_VERIFY}" == "true" ]]; then
    curl_opts+=(-k)
  fi

  curl "${curl_opts[@]}" \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/${VAULT_KV_MOUNT}/data/${path}"
}

map_secret_to_env() {
  local key="$1"
  case "${key}" in
    wallet_mnemonic)           echo "AKASH_WALLET_MNEMONIC" ;;
    mnemonic)                  echo "AKASH_WALLET_MNEMONIC" ;;
    auth_method)               echo "AKASH_AUTH_METHOD" ;;
    key_name)                  echo "AKASH_KEY_NAME" ;;
    keyring_backend)           echo "AKASH_KEYRING_BACKEND" ;;
    account_address)           echo "AKASH_ACCOUNT_ADDRESS" ;;
    provider_jwt)              echo "AKASH_JWT" ;;
    console_api_key)           echo "AKASH_CONSOLE_API_KEY" ;;
    certificate_path)          echo "AKASH_CERTIFICATE_PATH" ;;
    key_path)                  echo "AKASH_KEY_PATH" ;;
    rpc_endpoint)              echo "AKASH_RPC_ENDPOINT" ;;
    chain_id)                  echo "AKASH_CHAIN_ID" ;;
    gas_prices)                echo "AKASH_GAS_PRICES" ;;
    agentswarm_master_key)     echo "AGENTSWARM_MASTER_KEY" ;;
    gpu_cluster_keys)          echo "GPU_CLUSTER_KEYS" ;;
    solana_rpc_url)            echo "SOLANA_RPC_URL" ;;
    helius_api_key)            echo "HELIUS_API_KEY" ;;
    failover_rpc_list)         echo "FAILOVER_RPC_LIST" ;;
    birdeye_api_key)           echo "BIRDEYE_API_KEY" ;;
    jupiter_api_key)           echo "JUPITER_API_KEY" ;;
    raydium_api_key)           echo "RAYDIUM_API_KEY" ;;
    api_key)                   echo "RUNPOD_API_KEY" ;;
    api_token)                 echo "DIGITALOCEAN_API_TOKEN" ;;
    *)                         echo "${key^^}" ;;
  esac
}

inject_secrets() {
  local secrets_dir
  secrets_dir="$(dirname "${SECRETS_FILE}")"
  if ! mkdir -p "${secrets_dir}" 2>/dev/null; then
    SECRETS_FILE="/tmp/yieldswarm/app.env"
    secrets_dir="$(dirname "${SECRETS_FILE}")"
    mkdir -p "${secrets_dir}"
    log "Falling back to ${SECRETS_FILE} (not running as container user)"
  fi
  : > "${SECRETS_FILE}"
  chmod 600 "${SECRETS_FILE}"

  IFS=',' read -ra paths <<< "${VAULT_SECRET_PATHS}"
  for path in "${paths[@]}"; do
    path="$(echo "${path}" | xargs)"
    log "Fetching yieldswarm/${path}"
    local response
    response="$(fetch_kv_path "${path}")"

    local keys
    keys="$(echo "${response}" | jq -r '.data.data | keys[]')"
    while IFS= read -r key; do
      [[ -z "${key}" ]] && continue
      local value env_name
      value="$(echo "${response}" | jq -r --arg k "${key}" '.data.data[$k]')"
      env_name="$(map_secret_to_env "${key}")"
      printf '%s=%q\n' "${env_name}" "${value}" >> "${SECRETS_FILE}"
    done <<< "${keys}"
  done

  # shellcheck disable=SC1090
  set -a && source "${SECRETS_FILE}" && set +a
  log "Secrets loaded from ${SECRETS_FILE}"
}

validate_no_placeholders() {
  if grep -q 'REPLACE_ME' "${SECRETS_FILE}" 2>/dev/null; then
    log "ERROR: Vault secrets still contain REPLACE_ME placeholders"
    exit 1
  fi
}

main() {
  require_env VAULT_ADDR
  require_env VAULT_ROLE_ID
  require_env VAULT_SECRET_ID

  log "Authenticating to Vault at ${VAULT_ADDR}"
  vault_login
  inject_secrets
  validate_no_placeholders

  # Background health server for lease monitoring (/health, /healthz)
  if [[ -n "${HEALTH_PORT:-}" ]]; then
    log "Starting health server on :${HEALTH_PORT}"
    python agents/health_server.py &
  fi

  log "Starting workload: $*"
  exec "$@"
}

main "$@"

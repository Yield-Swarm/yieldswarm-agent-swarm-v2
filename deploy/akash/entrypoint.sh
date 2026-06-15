#!/usr/bin/env sh
set -eu

log() {
  printf '%s\n' "$*" >&2
}

require_env() {
  var_name="$1"
  eval "value=\${$var_name:-}"
  if [ -z "${value}" ]; then
    log "Missing required environment variable: ${var_name}"
    exit 1
  fi
}

vault_request() {
  method="$1"
  url="$2"
  body="${3:-}"
  token="${4:-}"

  attempts=0
  max_attempts=5
  while [ "$attempts" -lt "$max_attempts" ]; do
    attempts=$((attempts + 1))

    if [ "$method" = "GET" ]; then
      if [ -n "${VAULT_NAMESPACE}" ] && [ -n "$token" ]; then
        response="$(curl -fsS -H "X-Vault-Namespace: ${VAULT_NAMESPACE}" -H "X-Vault-Token: ${token}" "$url" 2>/dev/null)" || response=""
      elif [ -n "${VAULT_NAMESPACE}" ]; then
        response="$(curl -fsS -H "X-Vault-Namespace: ${VAULT_NAMESPACE}" "$url" 2>/dev/null)" || response=""
      elif [ -n "$token" ]; then
        response="$(curl -fsS -H "X-Vault-Token: ${token}" "$url" 2>/dev/null)" || response=""
      else
        response="$(curl -fsS "$url" 2>/dev/null)" || response=""
      fi
      if [ -n "$response" ]; then
        printf '%s' "$response"
        return 0
      fi
    else
      if [ -n "${VAULT_NAMESPACE}" ] && [ -n "$token" ]; then
        response="$(curl -fsS -X "$method" -H "X-Vault-Namespace: ${VAULT_NAMESPACE}" -H "X-Vault-Token: ${token}" -H "Content-Type: application/json" -d "$body" "$url" 2>/dev/null)" || response=""
      elif [ -n "${VAULT_NAMESPACE}" ]; then
        response="$(curl -fsS -X "$method" -H "X-Vault-Namespace: ${VAULT_NAMESPACE}" -H "Content-Type: application/json" -d "$body" "$url" 2>/dev/null)" || response=""
      elif [ -n "$token" ]; then
        response="$(curl -fsS -X "$method" -H "X-Vault-Token: ${token}" -H "Content-Type: application/json" -d "$body" "$url" 2>/dev/null)" || response=""
      else
        response="$(curl -fsS -X "$method" -H "Content-Type: application/json" -d "$body" "$url" 2>/dev/null)" || response=""
      fi
      if [ -n "$response" ]; then
        printf '%s' "$response"
        return 0
      fi
    fi

    sleep "$attempts"
  done

  log "Vault request failed after ${max_attempts} attempts: ${method} ${url}"
  return 1
}

export_secret_json() {
  secret_json="$1"
  while IFS='=' read -r k v; do
    export "${k}=${v}"
  done <<EOF
$(printf '%s' "$secret_json" | jq -r '
  to_entries[]
  | select(.key | test("^[A-Z0-9_]+$"))
  | "\(.key)=\(.value|tostring)"')
EOF
}

cleanup() {
  if [ -n "${VAULT_TOKEN:-}" ]; then
    if [ -n "${VAULT_NAMESPACE}" ]; then
      curl -fsS -X POST \
        -H "X-Vault-Namespace: ${VAULT_NAMESPACE}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/auth/token/revoke-self" >/dev/null 2>&1 || true
    else
      curl -fsS -X POST \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/auth/token/revoke-self" >/dev/null 2>&1 || true
    fi
  fi
}

require_env "VAULT_ADDR"
require_env "VAULT_ROLE_ID"
require_env "VAULT_SECRET_ID"
command -v curl >/dev/null 2>&1 || { log "curl is required"; exit 1; }
command -v jq >/dev/null 2>&1 || { log "jq is required"; exit 1; }

VAULT_NAMESPACE="${VAULT_NAMESPACE:-}"
VAULT_AUTH_PATH="${VAULT_AUTH_PATH:-approle}"
VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-kv}"
VAULT_AKASH_SECRET_PATH="${VAULT_AKASH_SECRET_PATH:-platform/runtime/akash}"
VAULT_RPC_SECRET_PATH="${VAULT_RPC_SECRET_PATH:-platform/rpc}"

auth_payload="$(jq -n --arg role_id "${VAULT_ROLE_ID}" --arg secret_id "${VAULT_SECRET_ID}" '{role_id:$role_id, secret_id:$secret_id}')"
auth_response="$(vault_request "POST" "${VAULT_ADDR}/v1/auth/${VAULT_AUTH_PATH}/login" "${auth_payload}")"
VAULT_TOKEN="$(printf '%s' "$auth_response" | jq -er '.auth.client_token')"
trap cleanup EXIT

unset VAULT_ROLE_ID
unset VAULT_SECRET_ID

akash_response="$(vault_request "GET" "${VAULT_ADDR}/v1/${VAULT_KV_MOUNT}/data/${VAULT_AKASH_SECRET_PATH}" "" "${VAULT_TOKEN}")"
rpc_response="$(vault_request "GET" "${VAULT_ADDR}/v1/${VAULT_KV_MOUNT}/data/${VAULT_RPC_SECRET_PATH}" "" "${VAULT_TOKEN}")"

akash_json="$(printf '%s' "$akash_response" | jq -ec '.data.data')"
rpc_json="$(printf '%s' "$rpc_response" | jq -ec '.data.data')"

export_secret_json "$akash_json"
export_secret_json "$rpc_json"

if [ "$#" -eq 0 ]; then
  set -- python /app/agents/akash-optimizer.py
fi

exec "$@"

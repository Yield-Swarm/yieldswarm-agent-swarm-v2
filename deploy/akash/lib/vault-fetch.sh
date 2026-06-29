#!/usr/bin/env bash
# Shared Vault KV fetch helpers for Akash deploy scripts.
# Used by setup-auth.sh and deploy.sh — never writes secrets to the repo.

set -euo pipefail

vault_deploy_login() {
  : "${VAULT_ADDR:?Set VAULT_ADDR}"
  : "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID}"
  : "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID}"

  local payload curl_opts=(-sS --fail)
  payload="$(jq -n \
    --arg role_id "${VAULT_ROLE_ID}" \
    --arg secret_id "${VAULT_SECRET_ID}" \
    '{role_id: $role_id, secret_id: $secret_id}')"

  if [[ "${VAULT_SKIP_VERIFY:-false}" == "true" ]]; then
    curl_opts+=(-k)
  fi

  VAULT_DEPLOY_TOKEN="$(
    curl "${curl_opts[@]}" \
      --request POST \
      --header "Content-Type: application/json" \
      --data "${payload}" \
      "${VAULT_ADDR}/v1/auth/approle/login" \
      | jq -r '.auth.client_token'
  )"

  if [[ -z "${VAULT_DEPLOY_TOKEN}" || "${VAULT_DEPLOY_TOKEN}" == "null" ]]; then
    echo "Vault AppRole login failed" >&2
    return 1
  fi
}

vault_fetch_akash_secrets() {
  local mount="${VAULT_KV_MOUNT:-yieldswarm}"
  local curl_opts=(-sS --fail)

  if [[ "${VAULT_SKIP_VERIFY:-false}" == "true" ]]; then
    curl_opts+=(-k)
  fi

  curl "${curl_opts[@]}" \
    --header "X-Vault-Token: ${VAULT_DEPLOY_TOKEN}" \
    "${VAULT_ADDR}/v1/${mount}/data/runtime/akash" \
    | jq -r '.data.data'
}

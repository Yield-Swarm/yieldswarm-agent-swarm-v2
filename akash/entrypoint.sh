#!/usr/bin/env bash
# YieldSwarm Akash container entrypoint.
# Waits for Vault Agent to render secrets, then starts agent workloads.
# No secrets are hardcoded — all values come from Vault at runtime.
set -euo pipefail

SECRETS_DIR="/opt/yieldswarm"
SECRETS_FILE="${SECRETS_DIR}/secrets.env"
RPC_FILE="${SECRETS_DIR}/rpc.env"
READY_MARKER="${SECRETS_DIR}/.secrets-ready"
VAULT_AGENT_CONFIG="${VAULT_AGENT_CONFIG:-/etc/vault/vault-agent.hcl}"
MAX_WAIT_SECONDS="${VAULT_AGENT_WAIT_SECONDS:-120}"

log() {
  echo "[entrypoint] $*"
}

die() {
  echo "[entrypoint] ERROR: $*" >&2
  exit 1
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    die "Required environment variable ${name} is not set"
  fi
}

write_vault_credentials() {
  require_env VAULT_ROLE_ID
  require_env VAULT_SECRET_ID

  install -d -m 700 /run/vault
  printf '%s' "${VAULT_ROLE_ID}" > /run/vault/role-id
  printf '%s' "${VAULT_SECRET_ID}" > /run/vault/secret-id
  chmod 600 /run/vault/role-id /run/vault/secret-id
  unset VAULT_SECRET_ID
}

start_vault_agent() {
  write_vault_credentials

  sed "s|VAULT_ADDR_PLACEHOLDER|${VAULT_ADDR}|g" "${VAULT_AGENT_CONFIG}" > /tmp/vault-agent.hcl

  log "Starting Vault Agent"
  vault agent -config=/tmp/vault-agent.hcl &
  VAULT_AGENT_PID=$!
}

wait_for_secrets() {
  local elapsed=0
  log "Waiting for Vault Agent to render secrets (max ${MAX_WAIT_SECONDS}s)"

  while [[ ! -f "${READY_MARKER}" ]]; do
    if ! kill -0 "${VAULT_AGENT_PID}" 2>/dev/null; then
      die "Vault Agent exited before secrets were ready"
    fi
    if (( elapsed >= MAX_WAIT_SECONDS )); then
      die "Timed out waiting for secrets after ${MAX_WAIT_SECONDS}s"
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  log "Secrets rendered successfully"
}

load_secrets() {
  if [[ -f "${SECRETS_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${SECRETS_FILE}"
    set +a
  else
    die "Secrets file not found: ${SECRETS_FILE}"
  fi

  if [[ -f "${RPC_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${RPC_FILE}"
    set +a
  fi
}

validate_secrets() {
  local required=(
    AGENTSWARM_MASTER_KEY
    SOLANA_RPC_URL
  )
  local key
  for key in "${required[@]}"; do
    if [[ -z "${!key:-}" ]]; then
      die "Required secret ${key} is empty after Vault injection"
    fi
  done
  log "Required secrets validated"
}

run_agents() {
  log "Starting YieldSwarm agents (shard=${AGENT_SHARD_ID:-0})"
  exec python3 -m agents.runner "$@"
}

main() {
  require_env VAULT_ADDR

  if [[ "${VAULT_SKIP:-false}" == "true" ]]; then
    log "VAULT_SKIP=true — skipping Vault Agent (local dev only)"
    load_secrets || die "No secrets file and Vault skipped"
  else
    start_vault_agent
    wait_for_secrets
    load_secrets
  fi

  validate_secrets
  run_agents "$@"
}

main "$@"

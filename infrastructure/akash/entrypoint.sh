#!/usr/bin/env bash
# =============================================================================
# YieldSwarm Akash entrypoint
# -----------------------------------------------------------------------------
# Runtime secret bootstrapping for OpenClaw / AgentSwarm containers.
#
# Flow:
#   1. Validate required env: VAULT_ADDR + (VAULT_WRAPPING_TOKEN | VAULT_SECRET_ID)
#   2. If VAULT_WRAPPING_TOKEN is set, unwrap it -> VAULT_SECRET_ID
#      (response-wrapped secret_ids are single-unwrap by design, so a
#       compromised container image can't replay the bootstrap)
#   3. AppRole login using VAULT_ROLE_ID + VAULT_SECRET_ID -> client token
#   4. Read KV v2 secrets at:
#        - <root>/<runtime_path>   (app secrets)
#        - <root>/<rpc_path>       (RPC + chain keys)
#        - <root>/runtime/akash    (akash wallet, optional)
#      and export them as environment variables for the workload.
#   5. Start a background token-renewer (periodic token).
#   6. exec the workload command. Secrets exist only in the child's env,
#      never on disk, never in image layers.
#
# Hardened behaviour:
#   * `set -euo pipefail`
#   * No `echo` of secret values; only counts.
#   * Renewer runs in subshell with `exec` so it cleanly inherits SIGTERM.
#   * Trap SIGTERM/SIGINT -> revoke own token before exit.
# =============================================================================

set -euo pipefail

log()  { printf '\033[1;36m[entrypoint]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[entrypoint]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[entrypoint]\033[0m %s\n' "$*" >&2; exit 1; }

require_env() {
  local v="$1"
  if [[ -z "${!v:-}" ]]; then
    die "required env var ${v} is not set"
  fi
}

# -----------------------------------------------------------------------------
# 0. Defaults
# -----------------------------------------------------------------------------
: "${VAULT_ADDR:?VAULT_ADDR is required}"
: "${VAULT_ROLE:=yieldswarm-akash}"
: "${VAULT_KV_MOUNT:=kv}"
: "${VAULT_SECRET_ROOT:=yieldswarm}"
: "${VAULT_RUNTIME_PATH:=runtime/openclaw}"
: "${VAULT_RPC_PATH:=rpc}"
: "${VAULT_AKASH_PATH:=runtime/akash}"
: "${VAULT_NAMESPACE:=}"
: "${APP_CMD:=}"

export VAULT_ADDR
[[ -n "$VAULT_NAMESPACE" ]] && export VAULT_NAMESPACE

# -----------------------------------------------------------------------------
# 1. Obtain a Vault secret_id
# -----------------------------------------------------------------------------
require_env VAULT_ROLE_ID

if [[ -n "${VAULT_WRAPPING_TOKEN:-}" ]]; then
  log "unwrapping response-wrapped secret_id"
  VAULT_SECRET_ID="$(
    VAULT_TOKEN="${VAULT_WRAPPING_TOKEN}" \
      vault unwrap -format=json \
      | jq -er '.data.secret_id'
  )" || die "failed to unwrap VAULT_WRAPPING_TOKEN"
  unset VAULT_WRAPPING_TOKEN
elif [[ -n "${VAULT_SECRET_ID:-}" ]]; then
  log "using pre-supplied VAULT_SECRET_ID (consider switching to wrapped tokens)"
else
  die "either VAULT_WRAPPING_TOKEN or VAULT_SECRET_ID must be set"
fi

# -----------------------------------------------------------------------------
# 2. AppRole login
# -----------------------------------------------------------------------------
log "logging in to Vault via AppRole role=${VAULT_ROLE}"
LOGIN_JSON="$(
  vault write -format=json auth/approle/login \
    role_id="${VAULT_ROLE_ID}" \
    secret_id="${VAULT_SECRET_ID}"
)" || die "AppRole login failed"

VAULT_TOKEN="$(jq -er '.auth.client_token' <<<"${LOGIN_JSON}")"
TOKEN_TTL="$(jq -er '.auth.lease_duration' <<<"${LOGIN_JSON}")"
RENEWABLE="$(jq -er '.auth.renewable' <<<"${LOGIN_JSON}")"
export VAULT_TOKEN
unset VAULT_SECRET_ID VAULT_ROLE_ID LOGIN_JSON
log "token acquired, ttl=${TOKEN_TTL}s renewable=${RENEWABLE}"

# -----------------------------------------------------------------------------
# 3. Fetch + export secrets
# -----------------------------------------------------------------------------
read_kv_into_env() {
  local subpath="$1" prefix="${2:-}"
  local full="${VAULT_SECRET_ROOT}/${subpath}"
  local json
  if ! json="$(vault kv get -mount="${VAULT_KV_MOUNT}" -format=json "${full}" 2>/dev/null)"; then
    warn "no secret at ${VAULT_KV_MOUNT}/${full} (skipping)"
    return 0
  fi

  local count=0
  while IFS= read -r kv; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    local exported_name
    if [[ -n "${prefix}" ]]; then
      exported_name="${prefix}_${key}"
    else
      exported_name="${key}"
    fi
    exported_name="$(printf '%s' "${exported_name}" | tr '[:lower:]-' '[:upper:]_')"
    # Ensure uppercase and valid identifier characters only.
    if [[ ! "${exported_name}" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
      warn "skipping invalid env var name: ${exported_name}"
      continue
    fi
    export "${exported_name}=${val}"
    count=$((count + 1))
  done < <(jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"' <<<"${json}")

  log "loaded ${count} keys from ${VAULT_KV_MOUNT}/${full}"
}

read_kv_into_env "${VAULT_RUNTIME_PATH}"
read_kv_into_env "${VAULT_RPC_PATH}" "RPC"
read_kv_into_env "${VAULT_AKASH_PATH}" "AKASH"

# -----------------------------------------------------------------------------
# 4. Token renewer (background)
# -----------------------------------------------------------------------------
renew_loop() {
  # Periodic tokens stay alive forever as long as we renew within `period`.
  # We renew at roughly half the TTL to be safe.
  while true; do
    local sleep_for=$(( TOKEN_TTL / 2 ))
    [[ "${sleep_for}" -lt 60 ]] && sleep_for=60
    sleep "${sleep_for}"
    if ! vault token renew -format=json >/dev/null 2>&1; then
      warn "vault token renew failed; will retry"
    fi
  done
}

if [[ "${RENEWABLE}" == "true" ]]; then
  renew_loop &
  RENEWER_PID=$!
  log "started token renewer pid=${RENEWER_PID}"
fi

# -----------------------------------------------------------------------------
# 5. Graceful shutdown - revoke own token
# -----------------------------------------------------------------------------
cleanup() {
  trap - SIGTERM SIGINT EXIT
  log "shutdown: revoking Vault token"
  vault token revoke -self >/dev/null 2>&1 || true
  if [[ -n "${RENEWER_PID:-}" ]]; then
    kill "${RENEWER_PID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${APP_PID:-}" ]]; then
    kill -TERM "${APP_PID}" >/dev/null 2>&1 || true
    wait "${APP_PID}" 2>/dev/null || true
  fi
}
trap cleanup SIGTERM SIGINT EXIT

# -----------------------------------------------------------------------------
# 6. Hand off to the workload
# -----------------------------------------------------------------------------
if [[ "$#" -gt 0 ]]; then
  log "exec args from CMD: $*"
  "$@" &
  APP_PID=$!
elif [[ -n "${APP_CMD}" ]]; then
  log "exec APP_CMD: ${APP_CMD}"
  bash -c "${APP_CMD}" &
  APP_PID=$!
else
  die "no workload command supplied (set APP_CMD or pass CMD args)"
fi

wait "${APP_PID}"
EXIT_CODE=$?
log "workload exited with code ${EXIT_CODE}"
exit "${EXIT_CODE}"

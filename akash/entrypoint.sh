#!/usr/bin/env bash
# akash/entrypoint.sh
#
# Container entrypoint for YieldSwarm Akash workers.
#
# Responsibilities:
#   1. Validate that the deployment provided a Vault address, role_id,
#      and a wrapped SecretID. None of these are secrets that can be
#      replayed: role_id is non-sensitive, and the wrapped SecretID is a
#      one-shot, short-TTL token.
#   2. Unwrap the SecretID into a tmpfs file Vault Agent will consume.
#   3. Start Vault Agent as a background process. It logs in via AppRole
#      and renders /run/secrets/agent.env from KVv2 templates.
#   4. Wait for the first successful render, source the env file, and
#      exec the workload (default: python -m yieldswarm.agent).
#   5. Propagate signals so SIGTERM stops both Vault Agent and the
#      workload cleanly (tini reaps zombies).
#
# Security guarantees:
#   - No secret ever lands on a writable, persistent disk. /run/secrets
#     is a tmpfs (declared in the Akash SDL) so contents vanish on
#     container restart.
#   - The wrapped SecretID is consumed exactly once; the file is removed
#     by Vault Agent (`remove_secret_id_file_after_reading = true`).
#   - The workload process never sees the wrap token or role_id - it
#     only sees the rendered env file.
#   - The Vault token sink is in tmpfs and mode 0400.

set -euo pipefail

log()  { printf '\033[1;36m[entrypoint]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[entrypoint]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- Required env from Akash SDL ---------------------------------------
: "${VAULT_ADDR:?VAULT_ADDR must be set by the Akash SDL}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID must be set by the Akash SDL}"
: "${AGENT_SHARD_ID:?AGENT_SHARD_ID must be set by the Akash SDL (0..119)}"

# Accept either name for the one-shot wrap token (deploy scripts use both).
WRAP_TOKEN="${VAULT_WRAPPED_SECRET_ID:-${VAULT_SECRET_ID_WRAP_TOKEN:-}}"
[ -n "${WRAP_TOKEN}" ] || die "VAULT_WRAPPED_SECRET_ID (or VAULT_SECRET_ID_WRAP_TOKEN) must be set by the Akash SDL"

export VAULT_ADDR AGENT_SHARD_ID

SECRETS_DIR="/run/secrets"
mkdir -p "${SECRETS_DIR}"
umask 077

# ---- Step 1: write role_id to tmpfs (non-sensitive) --------------------
printf '%s' "${VAULT_ROLE_ID}" > "${SECRETS_DIR}/role-id"
chmod 0400 "${SECRETS_DIR}/role-id"

# ---- Step 2: unwrap the SecretID once and write to tmpfs ---------------
log "Unwrapping SecretID for AppRole akash-runtime"
if ! UNWRAPPED=$(VAULT_TOKEN="${WRAP_TOKEN}" \
        vault unwrap -format=json 2>/tmp/unwrap.err); then
  cat /tmp/unwrap.err >&2 || true
  die "Failed to unwrap VAULT_WRAPPED_SECRET_ID. Has it expired or been used already?"
fi
unset VAULT_WRAPPED_SECRET_ID VAULT_SECRET_ID_WRAP_TOKEN WRAP_TOKEN

SECRET_ID=$(printf '%s' "${UNWRAPPED}" | jq -er '.data.secret_id' || true)
[ -n "${SECRET_ID:-}" ] || die "Unwrap succeeded but no .data.secret_id present."
printf '%s' "${SECRET_ID}" > "${SECRETS_DIR}/secret-id"
chmod 0400 "${SECRETS_DIR}/secret-id"
unset UNWRAPPED SECRET_ID

# ---- Step 3: launch Vault Agent in the background ----------------------
log "Starting Vault Agent (config: ${VAULT_AGENT_CONFIG})"
vault agent -config="${VAULT_AGENT_CONFIG}" \
  >/proc/1/fd/1 2>/proc/1/fd/2 &
AGENT_PID=$!

# Forward signals so the workload + agent shut down together.
shutdown() {
  log "Received signal, shutting down (agent_pid=${AGENT_PID}, workload_pid=${WORKLOAD_PID:-none})"
  if [ -n "${WORKLOAD_PID:-}" ]; then
    kill -TERM "${WORKLOAD_PID}" 2>/dev/null || true
    wait "${WORKLOAD_PID}" 2>/dev/null || true
  fi
  kill -TERM "${AGENT_PID}" 2>/dev/null || true
  wait "${AGENT_PID}" 2>/dev/null || true
  exit 0
}
trap shutdown TERM INT HUP

# ---- Step 4: wait for first render -------------------------------------
ENV_FILE="${AGENT_ENV_FILE:-/run/secrets/agent.env}"
log "Waiting up to 120s for Vault Agent to render ${ENV_FILE}"
for i in $(seq 1 120); do
  if [ -s "${ENV_FILE}" ]; then
    log "agent.env rendered after ${i}s"
    break
  fi
  if ! kill -0 "${AGENT_PID}" 2>/dev/null; then
    die "Vault Agent exited before rendering ${ENV_FILE}"
  fi
  sleep 1
done
[ -s "${ENV_FILE}" ] || die "Timed out waiting for ${ENV_FILE}"

# ---- Step 5: exec the workload with the rendered env -------------------
# Source the env file in a sub-shell so we can use `exec` for the workload.
set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

log "Starting workload: $*"
"$@" &
WORKLOAD_PID=$!

# Wait on either Vault Agent or the workload; if either dies, exit.
wait -n "${AGENT_PID}" "${WORKLOAD_PID}"
EXIT_CODE=$?
log "A primary process exited (code=${EXIT_CODE}); shutting down."
shutdown

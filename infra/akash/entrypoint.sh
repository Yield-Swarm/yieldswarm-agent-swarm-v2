#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Akash entrypoint for APN runtime containers.
#
# Responsibilities (in order):
#   1. Validate the AppRole credentials handed to the container.
#   2. Stage them under VAULT_RUN_DIR with strict perms.
#   3. Launch Vault Agent (AppRole auto-auth + KV templates).
#   4. Block until the first secret render completes.
#   5. Drop privileges and exec the swarm process so it inherits the
#      rendered env file.
#
# At no point does the script log a secret value or write one to a path
# outside VAULT_SECRETS_DIR (tmpfs, 0700 to the apn user).
# ---------------------------------------------------------------------------

set -euo pipefail

log() { printf '[apn-entrypoint] %s\n' "$*" >&2; }
die() { log "FATAL: $*"; exit 1; }

: "${VAULT_ADDR:?VAULT_ADDR must be provided to the Akash deployment}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID must be provided to the Akash deployment}"
: "${VAULT_SECRET_ID:?VAULT_SECRET_ID must be provided to the Akash deployment}"

export VAULT_NAMESPACE="${VAULT_NAMESPACE:-}"
export VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-kv}"
export VAULT_SECRET_PREFIX="${VAULT_SECRET_PREFIX:-apn}"
export VAULT_SECRETS_DIR="${VAULT_SECRETS_DIR:-/run/apn/secrets}"
export VAULT_RUN_DIR="${VAULT_RUN_DIR:-/run/apn/vault}"
export AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"
export AGENT_COUNT_TOTAL="${AGENT_COUNT_TOTAL:-10080}"
export AGENTS_PER_SHARD="${AGENTS_PER_SHARD:-84}"

install -d -m 0700 -o apn -g apn "${VAULT_RUN_DIR}" "${VAULT_SECRETS_DIR}"

# Stage role_id / secret_id on a tmpfs only Vault Agent can read.
role_id_file="${VAULT_RUN_DIR}/role-id"
secret_id_file="${VAULT_RUN_DIR}/secret-id"
umask 077
printf '%s' "${VAULT_ROLE_ID}"   > "${role_id_file}"
printf '%s' "${VAULT_SECRET_ID}" > "${secret_id_file}"
chown apn:apn "${role_id_file}" "${secret_id_file}"

# Wipe the secret-id from the process env before exec'ing children so
# nothing downstream can read it from /proc/<pid>/environ.
unset VAULT_SECRET_ID VAULT_ROLE_ID

log "starting Vault Agent (addr=${VAULT_ADDR}, mount=${VAULT_KV_MOUNT}, prefix=${VAULT_SECRET_PREFIX})"

# Run Vault Agent as the apn user so the rendered files are owned by
# the same uid that will exec the swarm process.
gosu apn:apn vault agent \
  -config=/etc/vault-agent/vault-agent.hcl \
  -log-level=info \
  -exit-after-auth=false &
vault_pid=$!

# Wait for the env file Vault Agent renders. We bound the wait to keep
# crash-looping containers cheap on Akash.
env_file="${VAULT_SECRETS_DIR}/apn.env"
deadline=$(( SECONDS + 60 ))
while [[ ! -s "${env_file}" ]]; do
  if (( SECONDS >= deadline )); then
    die "Vault Agent did not render ${env_file} within 60s; check Vault Agent logs above for an AppRole error."
  fi
  if ! kill -0 "${vault_pid}" 2>/dev/null; then
    die "Vault Agent exited before rendering secrets"
  fi
  sleep 1
done

log "secrets rendered; sourcing ${env_file} and execing ${*:-default CMD}"

# shellcheck disable=SC1090
set -a
. "${env_file}"
set +a

# Quick sanity check: the master key must always be present in prod.
if [[ -z "${AGENTSWARM_MASTER_KEY:-}" ]]; then
  die "AGENTSWARM_MASTER_KEY missing after Vault render; refusing to start"
fi

# Forward SIGTERM to Vault Agent so it revokes its token on shutdown.
trap 'log "received signal; revoking Vault token and stopping agent"; kill -TERM "${vault_pid}" 2>/dev/null || true; wait "${vault_pid}" 2>/dev/null || true; exit 0' TERM INT

# Drop to the apn user for the actual workload.
exec gosu apn:apn "$@"

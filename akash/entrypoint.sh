#!/usr/bin/env bash
# akash/entrypoint.sh
#
# Runtime secret injection for the Akash workload.
#
# Flow:
#   1. Validate required env vars (VAULT_ADDR, VAULT_ROLE_ID, plus exactly one of
#      VAULT_SECRET_ID or VAULT_SECRET_ID_WRAP_TOKEN).
#   2. If a wrap token was supplied, unwrap it ONCE to recover the secret_id
#      (the wrap token is single-use; the next pod restart needs a fresh one
#      issued by vault/scripts/issue-secret-id.sh akash-runtime).
#   3. Write the role_id + secret_id into a tmpfs file readable only by the
#      vault-agent process (mode 0400, owner yieldswarm).
#   4. Launch vault-agent in the background using /etc/vault-agent/config.hcl.
#   5. Wait until vault-agent renders /run/secrets/env.
#   6. Source /run/secrets/env into the process environment and exec the app
#      as the unprivileged `yieldswarm` user. The app sees the secrets via
#      environment variables and never touches Vault directly.
#
# Nothing here writes secrets to logs or to persistent storage.

set -Eeuo pipefail

log() { printf '[entrypoint] %s\n' "$*" >&2; }
die() { printf '[entrypoint][FATAL] %s\n' "$*" >&2; exit 1; }

: "${VAULT_ADDR:?VAULT_ADDR is required (e.g. https://vault.example.com:8200)}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID is required (set on the Akash SDL env)}"

SECRET_ID_FILE="/var/run/vault/secret_id"
ROLE_ID_FILE="/var/run/vault/role_id"
RENDERED_ENV="/run/secrets/env"

mkdir -p /var/run/vault /run/secrets
chown yieldswarm:yieldswarm /var/run/vault /run/secrets
chmod 0750 /var/run/vault /run/secrets

# ---------------------------------------------------------------------------
# Resolve secret_id (wrap-token unwrap path strongly preferred).
# ---------------------------------------------------------------------------
if [[ -n "${VAULT_SECRET_ID_WRAP_TOKEN:-}" ]]; then
  log "unwrapping VAULT_SECRET_ID_WRAP_TOKEN (one-shot)"
  # The unwrap call MUST be made with the wrap token as the auth token and
  # MUST succeed exactly once. After this, the wrap token is dead.
  unwrapped="$(VAULT_TOKEN="${VAULT_SECRET_ID_WRAP_TOKEN}" \
      vault unwrap -field=secret_id 2>/dev/null)"
  [[ -n "${unwrapped}" ]] || die "wrap token unwrap returned empty secret_id"
  VAULT_SECRET_ID="${unwrapped}"
  unset VAULT_SECRET_ID_WRAP_TOKEN
elif [[ -n "${VAULT_SECRET_ID:-}" ]]; then
  log "using pre-unwrapped VAULT_SECRET_ID from env"
else
  die "exactly one of VAULT_SECRET_ID_WRAP_TOKEN or VAULT_SECRET_ID must be set"
fi

# ---------------------------------------------------------------------------
# Persist credentials onto a tmpfs path that vault-agent can read. We do NOT
# rely on env vars beyond this point — vault-agent's auto-auth wants file paths.
# ---------------------------------------------------------------------------
umask 077
printf '%s' "${VAULT_ROLE_ID}"   > "${ROLE_ID_FILE}"
printf '%s' "${VAULT_SECRET_ID}" > "${SECRET_ID_FILE}"
chown yieldswarm:yieldswarm "${ROLE_ID_FILE}" "${SECRET_ID_FILE}"
chmod 0400 "${ROLE_ID_FILE}" "${SECRET_ID_FILE}"

# Wipe the in-process copies of the secret material before launching anything.
unset VAULT_ROLE_ID VAULT_SECRET_ID

# ---------------------------------------------------------------------------
# Start vault-agent. It auto-auths, renders the env template, and renews the
# token in the background. Run as the non-root app user.
# ---------------------------------------------------------------------------
log "starting vault-agent against ${VAULT_ADDR}"
gosu yieldswarm:yieldswarm \
    vault agent -config=/etc/vault-agent/config.hcl \
    -log-level="${VAULT_AGENT_LOG_LEVEL:-info}" &
agent_pid=$!

cleanup() {
  log "shutting down vault-agent (pid=${agent_pid})"
  kill -TERM "${agent_pid}" 2>/dev/null || true
  wait "${agent_pid}" 2>/dev/null || true
  rm -f "${SECRET_ID_FILE}" "${ROLE_ID_FILE}" "${RENDERED_ENV}"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Wait for the first render. 60s ceiling — if it doesn't come up, fail loud.
# ---------------------------------------------------------------------------
deadline=$(( $(date +%s) + 60 ))
while [[ ! -s "${RENDERED_ENV}" ]]; do
  if ! kill -0 "${agent_pid}" 2>/dev/null; then
    die "vault-agent exited before rendering ${RENDERED_ENV}"
  fi
  if (( $(date +%s) >= deadline )); then
    die "timed out waiting for vault-agent to render ${RENDERED_ENV}"
  fi
  sleep 1
done
log "secrets rendered to ${RENDERED_ENV}"

# ---------------------------------------------------------------------------
# Source the rendered env file into a child shell, then exec the app. The
# `set -a` ensures every assignment is exported. The env file is the *only*
# place the app gets its secrets from; once execed, the app can re-read it
# on SIGHUP if it wants live rotation (vault-agent rewrites it atomically
# whenever a lease comes up for renewal — see vault-agent/config.hcl).
# ---------------------------------------------------------------------------
log "exec: $*"
exec gosu yieldswarm:yieldswarm bash -c '
  set -a
  # shellcheck disable=SC1091
  source "$1"
  set +a
  shift
  exec "$@"
' bash "${RENDERED_ENV}" "$@"

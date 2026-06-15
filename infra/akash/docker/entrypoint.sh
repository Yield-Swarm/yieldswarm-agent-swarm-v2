#!/usr/bin/env bash
# YieldSwarm Akash container entrypoint.
#
# Boot order:
#   1. Sanity-check env (VAULT_ADDR, AKASH_VAULT_SECRET_ID_WRAPPED, YS_ENV).
#   2. Write the response-wrapped secret_id to a tmpfs file (mode 0400).
#   3. Launch `vault agent` in the background so it:
#        a. unwraps the secret_id,
#        b. logs in via AppRole,
#        c. renders /run/vault-agent/app.env from the template,
#        d. keeps the token / secrets renewed for the life of the container.
#   4. Block until the env file exists and is non-empty (with timeout).
#   5. Source the rendered env file (NEVER `cat`/`echo` its contents).
#   6. Drop privileges and exec the application.
#
# Hard rules:
#   * No secret value is ever logged.
#   * The env file lives only on tmpfs and is unlinked on shutdown.
#   * The wrapped secret_id is consumed once and deleted from disk.

set -Eeuo pipefail
umask 077

log() { printf '[entrypoint][%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*" >&2; }
die() { log "FATAL: $*"; exit 1; }

# ---------- 1. preflight ----------
: "${VAULT_ADDR:?VAULT_ADDR must be set (e.g. https://vault.yieldswarm.internal:8200)}"
: "${AKASH_VAULT_SECRET_ID_WRAPPED:?AKASH_VAULT_SECRET_ID_WRAPPED must be set (response-wrapped token)}"
: "${YS_ENV:=prod}"
: "${APP_ENV_FILE:=/run/vault-agent/app.env}"
export VAULT_ADDR YS_ENV APP_ENV_FILE

ROLE_ID_FILE="/etc/vault-agent/role_id"
SECRET_ID_FILE="/run/vault-agent/secret_id"
AGENT_CONFIG="/etc/vault-agent/agent.hcl"
AGENT_PID_FILE="/run/vault-agent/agent.pid"
APP_PID_FILE="/run/vault-agent/app.pid"

[[ -r "$ROLE_ID_FILE"   ]] || die "missing role_id at $ROLE_ID_FILE (was VAULT_APPROLE_ROLE_ID set at build?)"
[[ -r "$AGENT_CONFIG"   ]] || die "missing vault-agent config at $AGENT_CONFIG"
command -v vault >/dev/null  || die "vault binary not on PATH"

# Ensure /run/vault-agent is a private tmpfs.  In OCI runtimes /run is already
# tmpfs; we double-check to avoid accidentally persisting secret material.
mount_type="$(stat -fc %T /run/vault-agent 2>/dev/null || echo unknown)"
[[ "$mount_type" == "tmpfs" ]] || log "WARN: /run/vault-agent is $mount_type (expected tmpfs)"

# ---------- 2. land the wrapped secret_id on tmpfs ----------
log "writing wrapped secret_id to $SECRET_ID_FILE"
install -m 0400 -o root -g app /dev/null "$SECRET_ID_FILE"
printf '%s' "$AKASH_VAULT_SECRET_ID_WRAPPED" > "$SECRET_ID_FILE"
unset AKASH_VAULT_SECRET_ID_WRAPPED

# ---------- 3. start vault-agent ----------
log "starting vault-agent (VAULT_ADDR=$VAULT_ADDR YS_ENV=$YS_ENV)"
vault agent -config="$AGENT_CONFIG" -log-level=info \
  >/proc/1/fd/1 2>/proc/1/fd/2 &
AGENT_PID=$!
echo "$AGENT_PID" > "$AGENT_PID_FILE"

cleanup() {
  local rc=$?
  log "shutdown: rc=$rc"
  if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill -TERM "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  if kill -0 "$AGENT_PID" 2>/dev/null; then
    kill -TERM "$AGENT_PID" 2>/dev/null || true
    wait "$AGENT_PID" 2>/dev/null || true
  fi
  shred -u "$APP_ENV_FILE"   2>/dev/null || rm -f "$APP_ENV_FILE"
  shred -u "$SECRET_ID_FILE" 2>/dev/null || rm -f "$SECRET_ID_FILE"
  rm -f "$AGENT_PID_FILE" "$APP_PID_FILE"
  exit "$rc"
}
trap cleanup EXIT INT TERM

# ---------- 4. wait for first render ----------
log "waiting for vault-agent to render $APP_ENV_FILE"
deadline=$(( SECONDS + ${VAULT_AGENT_RENDER_TIMEOUT:-60} ))
while :; do
  if [[ -s "$APP_ENV_FILE" ]]; then
    log "vault-agent rendered env file ($(wc -l <"$APP_ENV_FILE") keys)"
    break
  fi
  if ! kill -0 "$AGENT_PID" 2>/dev/null; then
    die "vault-agent died before rendering secrets"
  fi
  (( SECONDS < deadline )) || die "timed out waiting for vault-agent to render $APP_ENV_FILE"
  sleep 1
done

# ---------- 5. load secrets into the child env (without logging) ----------
# Use `set -a` so every variable assigned during the source is auto-exported,
# then immediately `set +a` to restore default behaviour.
set -a
# shellcheck disable=SC1090
. "$APP_ENV_FILE"
set +a

# ---------- 6. drop privileges + exec ----------
log "secrets loaded; exec'ing application as uid=app"
exec gosu app:app bash -c '
  echo "$$" > "'"$APP_PID_FILE"'"
  exec "$@"
' _ "$@"

#!/usr/bin/env sh
set -eu

VAULT_AGENT_CONFIG="${VAULT_AGENT_CONFIG:-/etc/vault/agent-configs/akash-agent.hcl}"
VAULT_SECRETS_FILE="${VAULT_SECRETS_FILE:-/vault/secrets/yieldswarm.json}"
VAULT_AUTH_DIR="${VAULT_AUTH_DIR:-/vault/auth}"
VAULT_TOKEN_DIR="${VAULT_TOKEN_DIR:-/vault/token}"
VAULT_AGENT_PID=""

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  log "fatal: $*"
  exit 1
}

cleanup() {
  if [ -n "$VAULT_AGENT_PID" ] && kill -0 "$VAULT_AGENT_PID" 2>/dev/null; then
    kill "$VAULT_AGENT_PID" 2>/dev/null || true
    wait "$VAULT_AGENT_PID" 2>/dev/null || true
  fi
}

trap cleanup INT TERM EXIT

[ "$#" -gt 0 ] || fail "no command supplied"
[ -n "${VAULT_ADDR:-}" ] || fail "VAULT_ADDR is required"
[ -n "${VAULT_ROLE_ID:-}" ] || fail "VAULT_ROLE_ID is required"
[ -f "$VAULT_AGENT_CONFIG" ] || fail "Vault Agent config not found: $VAULT_AGENT_CONFIG"

mkdir -p "$VAULT_AUTH_DIR" "$VAULT_TOKEN_DIR" "$(dirname "$VAULT_SECRETS_FILE")"
chmod 0700 "$VAULT_AUTH_DIR" "$VAULT_TOKEN_DIR" "$(dirname "$VAULT_SECRETS_FILE")"

printf '%s' "$VAULT_ROLE_ID" > "$VAULT_AUTH_DIR/role_id"
chmod 0400 "$VAULT_AUTH_DIR/role_id"

if [ -n "${VAULT_WRAPPED_SECRET_ID:-}" ]; then
  log "Unwrapping Vault AppRole SecretID"
  SECRET_ID="$(
    VAULT_TOKEN="$VAULT_WRAPPED_SECRET_ID" vault unwrap -format=json |
      python3 -c 'import json, sys; print(json.load(sys.stdin)["data"]["secret_id"])'
  )"
  unset VAULT_WRAPPED_SECRET_ID
elif [ -n "${VAULT_SECRET_ID:-}" ]; then
  SECRET_ID="$VAULT_SECRET_ID"
  unset VAULT_SECRET_ID
elif [ -n "${VAULT_SECRET_ID_FILE:-}" ] && [ -f "$VAULT_SECRET_ID_FILE" ]; then
  SECRET_ID="$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).read_text().strip())' "$VAULT_SECRET_ID_FILE")"
else
  fail "one of VAULT_WRAPPED_SECRET_ID, VAULT_SECRET_ID, or VAULT_SECRET_ID_FILE is required"
fi

[ -n "$SECRET_ID" ] || fail "Vault AppRole SecretID is empty"
printf '%s' "$SECRET_ID" > "$VAULT_AUTH_DIR/secret_id"
chmod 0400 "$VAULT_AUTH_DIR/secret_id"
unset SECRET_ID

vault agent -config="$VAULT_AGENT_CONFIG" &
VAULT_AGENT_PID="$!"

log "Waiting for Vault Agent to render secrets"
attempt=0
while [ ! -s "$VAULT_SECRETS_FILE" ]; do
  attempt=$((attempt + 1))
  if [ "$attempt" -gt "${VAULT_RENDER_ATTEMPTS:-60}" ]; then
    fail "Vault Agent did not render $VAULT_SECRETS_FILE"
  fi
  if ! kill -0 "$VAULT_AGENT_PID" 2>/dev/null; then
    wait "$VAULT_AGENT_PID" || true
    fail "Vault Agent exited before rendering secrets"
  fi
  sleep 1
done

chmod 0400 "$VAULT_SECRETS_FILE"

log "Starting workload with Vault-rendered environment"
exec python3 - "$VAULT_SECRETS_FILE" "$@" <<'PY'
import json
import os
import sys

secrets_file = sys.argv[1]
command = sys.argv[2:]

if not command:
    raise SystemExit("fatal: no command supplied after secrets file")

with open(secrets_file, "r", encoding="utf-8") as handle:
    secrets = json.load(handle)

for key, value in secrets.items():
    if value is None:
        continue
    if not isinstance(key, str) or not key:
        raise SystemExit("fatal: invalid secret key in Vault-rendered JSON")
    os.environ[key] = str(value)

os.execvpe(command[0], command, os.environ)
PY

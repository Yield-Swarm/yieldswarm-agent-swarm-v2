#!/usr/bin/env bash
# =============================================================================
# docker-entrypoint.sh
# -----------------------------------------------------------------------------
# AgentSwarm container entrypoint. Responsibilities, in order:
#
#   1. Validate that VAULT_ADDR, VAULT_ROLE_ID, and a VAULT_SECRET_ID source
#      are set. Refuses to start otherwise - we NEVER fall back to baked-in
#      defaults.
#
#   2. Materialise the secret_id from one of (in priority order):
#         a. $VAULT_SECRET_ID_FILE   <-- bind-mounted file (preferred)
#         b. $VAULT_SECRET_ID_WRAP_TOKEN  <-- response-wrapped one-shot token
#         c. $VAULT_SECRET_ID        <-- plain env var (last resort, dev only)
#
#   3. Launch supervisord, which in turn runs:
#         - vault-agent (auto-auth via AppRole + templates env files)
#         - wait-for-secrets.sh (blocks until templates are rendered)
#         - the actual workload (passed as CMD by the Dockerfile)
#
# All output is JSON-structured for easy ingestion by Loki / Azure Log
# Analytics.
# =============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit

log() {
  local lvl="$1"; shift
  printf '{"ts":"%s","level":"%s","msg":%s,"component":"entrypoint"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$lvl" "$(printf '%s' "$*" | jq -Rs .)"
}

die() {
  log ERROR "$*"
  exit 1
}

# ---------- 1. validate env -------------------------------------------------
: "${VAULT_ADDR:?VAULT_ADDR is required}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID is required}"

if [[ -n "${VAULT_NAMESPACE:-}" ]]; then
  export VAULT_NAMESPACE
fi

# ---------- 2. materialise secret_id ---------------------------------------
SECRET_ID_PATH="/var/run/vault-agent/secret-id"
install -d -m 0700 -o agentswarm -g agentswarm /var/run/vault-agent

if [[ -n "${VAULT_SECRET_ID_FILE:-}" ]]; then
  log INFO "Reading secret_id from file: $VAULT_SECRET_ID_FILE"
  install -m 0400 -o agentswarm -g agentswarm "$VAULT_SECRET_ID_FILE" "$SECRET_ID_PATH"

elif [[ -n "${VAULT_SECRET_ID_WRAP_TOKEN:-}" ]]; then
  log INFO "Unwrapping response-wrapped secret_id from VAULT_SECRET_ID_WRAP_TOKEN"
  unwrapped="$(
    VAULT_TOKEN="$VAULT_SECRET_ID_WRAP_TOKEN" \
      vault unwrap -format=json - </dev/null \
      | jq -r '.data.secret_id'
  )"
  if [[ -z "$unwrapped" || "$unwrapped" == "null" ]]; then
    die "Failed to unwrap secret_id (token expired or already used?)"
  fi
  printf '%s' "$unwrapped" > "$SECRET_ID_PATH"
  chown agentswarm:agentswarm "$SECRET_ID_PATH"
  chmod 0400 "$SECRET_ID_PATH"
  unset VAULT_SECRET_ID_WRAP_TOKEN
  unset unwrapped

elif [[ -n "${VAULT_SECRET_ID:-}" ]]; then
  log WARN "Using plain VAULT_SECRET_ID env var (acceptable in dev only)"
  printf '%s' "$VAULT_SECRET_ID" > "$SECRET_ID_PATH"
  chown agentswarm:agentswarm "$SECRET_ID_PATH"
  chmod 0400 "$SECRET_ID_PATH"
  unset VAULT_SECRET_ID

else
  die "No secret_id source. Set one of VAULT_SECRET_ID_FILE, VAULT_SECRET_ID_WRAP_TOKEN, or VAULT_SECRET_ID."
fi

log INFO "secret_id materialised at $SECRET_ID_PATH"

# ---------- 3. write role_id where vault-agent expects it -------------------
ROLE_ID_PATH="/var/run/vault-agent/role-id"
printf '%s' "$VAULT_ROLE_ID" > "$ROLE_ID_PATH"
chown agentswarm:agentswarm "$ROLE_ID_PATH"
chmod 0400 "$ROLE_ID_PATH"

# ---------- 4. start supervisord (vault-agent + app) -----------------------
export PATH="/usr/local/bin:$PATH"

log INFO "Launching supervisord (vault-agent + app)"

# The Dockerfile's CMD is forwarded so individual deployments can override.
if [[ "$#" -gt 0 ]]; then
  export AGENTSWARM_APP_CMD="$*"
else
  export AGENTSWARM_APP_CMD="python -m agentswarm"
fi

exec /usr/bin/supervisord -n -c /etc/agentswarm/supervisord.conf

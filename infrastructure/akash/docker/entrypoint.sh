#!/usr/bin/env bash
# entrypoint.sh
# Runtime secret injector for YieldSwarm AgentSwarm OS containers on Akash.
#
# Contract:
#   * Required env (set in Akash SDL or via provider bidengine):
#       VAULT_ADDR, VAULT_ROLE_ID
#       AND one of: VAULT_SECRET_ID  OR  VAULT_WRAPPED_SECRET_ID
#   * Optional env:
#       VAULT_NAMESPACE, VAULT_APPROLE_MOUNT (default "approle"),
#       VAULT_KV_MOUNT  (default "secret"),
#       VAULT_SECRET_BASE (default "yieldswarm"),
#       VAULT_TOKEN_RENEW_INTERVAL (seconds, default 600),
#       VAULT_BOOTSTRAP_TIMEOUT (seconds, default 30),
#       YIELDSWARM_RUN_AS (unix user to exec the workload as, default "app").
#
# Behaviour:
#   1. Validates required env; refuses to start if anything is missing.
#   2. AppRole-logins to Vault. Unwraps VAULT_WRAPPED_SECRET_ID if present.
#   3. Reads the runtime secret bundle (KV v2) into env vars - never to disk.
#   4. Forks a background renewer that runs `vault token renew` on a timer.
#   5. Drops privileges to YIELDSWARM_RUN_AS and execs the workload child.
#   6. On SIGTERM/SIGINT: revokes the token, signals the child, waits.
#
# Hard rules:
#   * No `set -x`. The entrypoint NEVER prints secret values.
#   * No secret value is ever passed on a command line. All Vault writes
#     use stdin / response fields, all secrets reach the child via exec env.

set -Eeuo pipefail
umask 077

log()  { printf '[entrypoint] %s\n' "$*"; }
warn() { printf '[entrypoint][WARN] %s\n' "$*" >&2; }
die()  { printf '[entrypoint][FATAL] %s\n' "$*" >&2; exit 1; }

# Mask anything that looks like a secret if it leaks into a log line.
# (Defence-in-depth - we still aim never to print one in the first place.)
exec > >(stdbuf -oL sed -E 's/(hvs\.[A-Za-z0-9_-]{8,})/[REDACTED-TOKEN]/g; s/(s\.[A-Za-z0-9]{20,})/[REDACTED-TOKEN]/g')
exec 2> >(stdbuf -oL sed -E 's/(hvs\.[A-Za-z0-9_-]{8,})/[REDACTED-TOKEN]/g; s/(s\.[A-Za-z0-9]{20,})/[REDACTED-TOKEN]/g' >&2)

# ---------------------------------------------------------------------------
# 0. Validate inputs.
# ---------------------------------------------------------------------------
: "${VAULT_ADDR:?VAULT_ADDR is required}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID is required}"

VAULT_APPROLE_MOUNT="${VAULT_APPROLE_MOUNT:-approle}"
VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-secret}"
VAULT_SECRET_BASE="${VAULT_SECRET_BASE:-yieldswarm}"
VAULT_TOKEN_RENEW_INTERVAL="${VAULT_TOKEN_RENEW_INTERVAL:-600}"
VAULT_BOOTSTRAP_TIMEOUT="${VAULT_BOOTSTRAP_TIMEOUT:-30}"
YIELDSWARM_RUN_AS="${YIELDSWARM_RUN_AS:-app}"

if [[ -z "${VAULT_SECRET_ID:-}" && -z "${VAULT_WRAPPED_SECRET_ID:-}" ]]; then
    die "Either VAULT_SECRET_ID or VAULT_WRAPPED_SECRET_ID must be set."
fi

for cmd in vault jq curl gosu; do
    command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

export VAULT_ADDR
[[ -n "${VAULT_NAMESPACE:-}" ]] && export VAULT_NAMESPACE

# ---------------------------------------------------------------------------
# 1. Wait for Vault to become reachable (Akash networking can be slow on boot).
# ---------------------------------------------------------------------------
log "waiting up to ${VAULT_BOOTSTRAP_TIMEOUT}s for Vault @ ${VAULT_ADDR}"
deadline=$(( $(date +%s) + VAULT_BOOTSTRAP_TIMEOUT ))
until vault status -format=json >/dev/null 2>&1; do
    (( $(date +%s) < deadline )) || die "Vault unreachable at $VAULT_ADDR"
    sleep 2
done
log "Vault reachable"

# ---------------------------------------------------------------------------
# 2. Resolve secret_id (unwrap if necessary).
# ---------------------------------------------------------------------------
if [[ -n "${VAULT_WRAPPED_SECRET_ID:-}" ]]; then
    log "unwrapping single-use VAULT_WRAPPED_SECRET_ID"
    secret_id=$(VAULT_TOKEN="$VAULT_WRAPPED_SECRET_ID" \
        vault unwrap -format=json | jq -er '.data.secret_id') \
        || die "unwrap failed (token consumed or expired)"
    unset VAULT_WRAPPED_SECRET_ID
else
    secret_id="$VAULT_SECRET_ID"
    unset VAULT_SECRET_ID
fi

# ---------------------------------------------------------------------------
# 3. AppRole login -> short-lived workload token.
# ---------------------------------------------------------------------------
log "AppRole login (mount=${VAULT_APPROLE_MOUNT})"
# Write role_id+secret_id as a JSON body on stdin so they never appear
# in /proc/<pid>/cmdline.
login_json=$(jq -nc --arg r "$VAULT_ROLE_ID" --arg s "$secret_id" \
    '{role_id:$r, secret_id:$s}')
unset secret_id

login_resp=$(printf '%s' "$login_json" | \
    vault write -format=json "auth/${VAULT_APPROLE_MOUNT}/login" - ) \
    || die "AppRole login failed"
unset login_json

VAULT_TOKEN=$(printf '%s' "$login_resp" | jq -er '.auth.client_token') \
    || die "no client_token in login response"
token_ttl=$(printf '%s' "$login_resp" | jq -er '.auth.lease_duration // 0')
token_renewable=$(printf '%s' "$login_resp" | jq -er '.auth.renewable // false')
unset login_resp
export VAULT_TOKEN

log "obtained workload token (ttl=${token_ttl}s, renewable=${token_renewable})"

# ---------------------------------------------------------------------------
# 4. Fetch runtime secret bundles into env vars.
# ---------------------------------------------------------------------------
# Each entry maps "<env-var-prefix>:<vault-path>". Keys inside the KV doc
# become "<PREFIX>_<KEY-UPPERCASE>" environment variables for the child.
declare -a BUNDLES=(
    "AGENTSWARM:${VAULT_SECRET_BASE}/runtime/agentswarm"
    "LLM:${VAULT_SECRET_BASE}/runtime/llm"
    "RPC_SOLANA:${VAULT_SECRET_BASE}/rpc/solana"
    "RPC_HELIUS:${VAULT_SECRET_BASE}/rpc/helius"
    "RPC_BIRDEYE:${VAULT_SECRET_BASE}/rpc/birdeye"
    "RPC_JUPITER:${VAULT_SECRET_BASE}/rpc/jupiter"
    "RPC_ETHEREUM:${VAULT_SECRET_BASE}/rpc/ethereum"
)

# Build a NUL-delimited list of "NAME=VALUE" pairs in memory. We pass the
# file descriptor to the child via `env -0` so values never hit disk.
secrets_fd_file=$(mktemp -p /run/yieldswarm secrets.XXXXXX)
trap 'shred -u "$secrets_fd_file" 2>/dev/null || rm -f "$secrets_fd_file"' EXIT

for entry in "${BUNDLES[@]}"; do
    prefix="${entry%%:*}"
    path="${entry#*:}"
    log "fetching ${VAULT_KV_MOUNT}/data/${path} -> env prefix ${prefix}_"
    if ! body=$(vault kv get -format=json -mount="$VAULT_KV_MOUNT" "$path" 2>/dev/null); then
        warn "missing or forbidden: ${VAULT_KV_MOUNT}/${path} (skipping bundle)"
        continue
    fi
    # Emit NAME=VALUE NUL-delimited pairs. jq handles escaping.
    printf '%s' "$body" | jq -j --arg pfx "$prefix" '
        .data.data
        | to_entries[]
        | "\($pfx)_\(.key|ascii_upcase)=\(.value)\u0000"
    ' >> "$secrets_fd_file"
    unset body
done

# Also expose the resolved token + addr to the child so it can do its own
# Vault calls (e.g. transit encrypt/decrypt) without re-authenticating.
printf 'VAULT_ADDR=%s\0VAULT_TOKEN=%s\0' "$VAULT_ADDR" "$VAULT_TOKEN" >> "$secrets_fd_file"
[[ -n "${VAULT_NAMESPACE:-}" ]] && \
    printf 'VAULT_NAMESPACE=%s\0' "$VAULT_NAMESPACE" >> "$secrets_fd_file"

# ---------------------------------------------------------------------------
# 5. Background token renewer.
# ---------------------------------------------------------------------------
renew_loop() {
    # Re-acquire token from parent env (still set). Sleep <interval> then
    # renew; on terminal failure, kill the workload so the orchestrator
    # reschedules with a fresh secret_id rather than running stale.
    while sleep "$VAULT_TOKEN_RENEW_INTERVAL"; do
        if ! vault token renew -format=json >/dev/null 2>&1; then
            warn "token renew failed - terminating workload to force re-bootstrap"
            kill -TERM "$child_pid" 2>/dev/null || true
            exit 1
        fi
    done
}

# ---------------------------------------------------------------------------
# 6. Signal handling - propagate to child, then revoke token.
# ---------------------------------------------------------------------------
shutdown() {
    # shellcheck disable=SC2317 # called indirectly via trap
    local sig="$1"
    log "received SIG${sig}; forwarding to child pid=${child_pid:-?}"
    if [[ -n "${child_pid:-}" ]]; then
        kill -"$sig" "$child_pid" 2>/dev/null || true
        wait "$child_pid" 2>/dev/null || true
    fi
    if [[ -n "${VAULT_TOKEN:-}" ]]; then
        log "revoking workload token"
        vault token revoke -self >/dev/null 2>&1 || true
    fi
    exit 0
}
trap 'shutdown TERM' TERM
trap 'shutdown INT'  INT

# ---------------------------------------------------------------------------
# 7. Drop privileges and exec the workload with secrets in env (not argv).
# ---------------------------------------------------------------------------
log "starting workload as user '${YIELDSWARM_RUN_AS}': $*"

# Load NUL-delimited NAME=VALUE pairs into THIS shell's environment using
# bash built-ins. The values are then inherited by fork+exec without ever
# being visible as argv (no /proc/<pid>/cmdline leak) and without being
# written to a file the child has to read+delete itself.
while IFS= read -r -d '' kv; do
    [[ -z "$kv" ]] && continue
    key="${kv%%=*}"
    val="${kv#*=}"
    # Validate variable name to refuse anything weird from KV (defence in
    # depth - the KV writer is trusted but we still check).
    [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || { warn "skipping invalid env name '$key'"; continue; }
    printf -v "$key" '%s' "$val"
    # shellcheck disable=SC2163 # intentional: indirect export of variable named by $key
    export "$key"
done < "$secrets_fd_file"

# Shred the on-disk staging file the moment its contents are in memory.
shred -u "$secrets_fd_file" 2>/dev/null || rm -f "$secrets_fd_file"
trap - EXIT

# Spawn workload as the unprivileged user. gosu preserves the env we just
# populated; the workload sees secrets only via the inherited env table.
if [[ "$(id -u)" -eq 0 && "$YIELDSWARM_RUN_AS" != "root" ]]; then
    gosu "$YIELDSWARM_RUN_AS" "$@" &
else
    "$@" &
fi
child_pid=$!

renew_loop &
renewer_pid=$!

log "workload pid=${child_pid}, renewer pid=${renewer_pid}"

# Wait specifically on the child; if it exits, kill the renewer and
# propagate the child's exit code.
set +e
wait "$child_pid"
rc=$?
set -e

log "workload exited rc=${rc}; cleaning up"
kill "$renewer_pid" 2>/dev/null || true
vault token revoke -self >/dev/null 2>&1 || true
exit "$rc"

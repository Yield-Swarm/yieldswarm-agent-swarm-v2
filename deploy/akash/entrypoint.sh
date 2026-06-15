#!/usr/bin/env sh
#
# entrypoint.sh — Runtime secret injection for the YieldSwarm Akash deployment.
#
# At container start this script:
#   1. Authenticates to Vault (AppRole, preferring a response-wrapped SecretID;
#      or a direct VAULT_TOKEN for local development).
#   2. Reads the application + RPC secret bundles from Vault KV v2.
#   3. Exports every key as an environment variable for the application process.
#   4. Drops its own Vault token from the child environment and (by default)
#      revokes it, so the running app holds no Vault credential it does not need.
#
# NOTHING is ever hardcoded: no secret values, no tokens, no endpoints. Secrets
# live only in process memory and are never written to disk or logged.
#
# Required environment (provided by the Akash SDL / operator):
#   VAULT_ADDR                       Vault server address.
#   VAULT_ROLE_ID                    AppRole RoleID (non-sensitive).
#   one of:
#     VAULT_SECRET_ID_WRAPPING_TOKEN Response-wrapping token for the SecretID
#                                    (RECOMMENDED — short-lived, single-use).
#     VAULT_SECRET_ID                Raw AppRole SecretID (less safe).
#     VAULT_TOKEN                    Pre-issued token (local/dev only).
#
# Optional environment:
#   VAULT_APPROLE_PATH               AppRole mount   (default: approle)
#   VAULT_KV_MOUNT                   KV v2 mount     (default: secret)
#   VAULT_APP_PATH                   App secret path (default: yieldswarm/app)
#   VAULT_RPC_PATH                   RPC secret path (default: yieldswarm/rpc)
#   VAULT_NAMESPACE                  Vault Enterprise/HCP namespace.
#   VAULT_CACERT                     Path to a CA bundle for TLS verification.
#   VAULT_REVOKE_TOKEN_AFTER_LOAD    Revoke the token after loading (default: true)
#   VAULT_SKIP_VERIFY                Set to "true" to skip TLS verify (NOT for prod)
#
set -eu

log()  { printf '[entrypoint] %s\n' "$*" >&2; }
die()  { printf '[entrypoint] FATAL: %s\n' "$*" >&2; exit 1; }

command -v vault >/dev/null 2>&1 || die "vault CLI not found in image."
command -v jq    >/dev/null 2>&1 || die "jq not found in image."

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
export VAULT_ADDR

VAULT_APPROLE_PATH="${VAULT_APPROLE_PATH:-approle}"
VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-secret}"
VAULT_APP_PATH="${VAULT_APP_PATH:-yieldswarm/app}"
VAULT_RPC_PATH="${VAULT_RPC_PATH:-yieldswarm/rpc}"
VAULT_REVOKE_TOKEN_AFTER_LOAD="${VAULT_REVOKE_TOKEN_AFTER_LOAD:-true}"

[ -n "${VAULT_NAMESPACE:-}" ] && export VAULT_NAMESPACE
[ -n "${VAULT_CACERT:-}" ] && export VAULT_CACERT
if [ "${VAULT_SKIP_VERIFY:-false}" = "true" ]; then
  export VAULT_SKIP_VERIFY=true
  log "WARNING: TLS verification disabled (VAULT_SKIP_VERIFY=true). Do not use in production."
fi

# --- 1. Authenticate --------------------------------------------------------
authenticate() {
  if [ -n "${VAULT_TOKEN:-}" ]; then
    log "Using pre-supplied VAULT_TOKEN."
    export VAULT_TOKEN
    return 0
  fi

  [ -n "${VAULT_ROLE_ID:-}" ] || die "Provide VAULT_TOKEN, or VAULT_ROLE_ID with a SecretID."

  _secret_id=""
  if [ -n "${VAULT_SECRET_ID_WRAPPING_TOKEN:-}" ]; then
    log "Unwrapping response-wrapped SecretID."
    _secret_id="$(VAULT_TOKEN="${VAULT_SECRET_ID_WRAPPING_TOKEN}" \
      vault unwrap -field=secret_id 2>/dev/null)" \
      || die "Failed to unwrap SecretID (token expired or already used?)."
  elif [ -n "${VAULT_SECRET_ID:-}" ]; then
    _secret_id="${VAULT_SECRET_ID}"
  else
    die "Provide VAULT_SECRET_ID_WRAPPING_TOKEN (recommended) or VAULT_SECRET_ID."
  fi

  log "Logging in via AppRole '${VAULT_APPROLE_PATH}'."
  VAULT_TOKEN="$(vault write -field=token \
    "auth/${VAULT_APPROLE_PATH}/login" \
    role_id="${VAULT_ROLE_ID}" \
    secret_id="${_secret_id}")" \
    || die "AppRole login failed."
  export VAULT_TOKEN

  # Scrub the SecretID from memory immediately after use.
  _secret_id=""
  unset _secret_id VAULT_SECRET_ID VAULT_SECRET_ID_WRAPPING_TOKEN
}

# --- 2/3. Load a KV v2 path and emit shell `export` statements --------------
# Keys are exported verbatim (they are stored as exact env var names in Vault).
emit_exports() {
  _path="$1"
  vault kv get -mount="${VAULT_KV_MOUNT}" -format=json "${_path}" 2>/dev/null \
    | jq -r '.data.data | to_entries[] | "export \(.key)=\(.value | @sh)"' \
    || die "Failed to read secrets from ${VAULT_KV_MOUNT}/${_path} (policy or path missing?)."
}

authenticate

log "Loading application secrets from ${VAULT_KV_MOUNT}/${VAULT_APP_PATH}."
_app_exports="$(emit_exports "${VAULT_APP_PATH}")"
log "Loading RPC secrets from ${VAULT_KV_MOUNT}/${VAULT_RPC_PATH}."
_rpc_exports="$(emit_exports "${VAULT_RPC_PATH}")"

# Apply the exports into this shell's environment.
eval "${_app_exports}"
eval "${_rpc_exports}"
_app_count="$(printf '%s\n' "${_app_exports}" | grep -c '^export ' || true)"
_rpc_count="$(printf '%s\n' "${_rpc_exports}" | grep -c '^export ' || true)"
log "Injected ${_app_count} application + ${_rpc_count} RPC secret(s) into the environment."
unset _app_exports _rpc_exports _app_count _rpc_count

# --- 4. Drop the Vault credential before handing off to the app -------------
if [ "${VAULT_REVOKE_TOKEN_AFTER_LOAD}" = "true" ]; then
  if vault token revoke -self >/dev/null 2>&1; then
    log "Revoked Vault token (least privilege)."
  else
    log "WARNING: could not revoke Vault token."
  fi
fi
unset VAULT_TOKEN

if [ "$#" -eq 0 ]; then
  die "No command provided to exec. Set CMD in the image or Akash SDL."
fi

log "Starting application: $*"
exec "$@"

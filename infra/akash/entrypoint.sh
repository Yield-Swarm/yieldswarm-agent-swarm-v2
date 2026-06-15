#!/usr/bin/env bash
# =============================================================================
# YieldSwarm — Vault-aware container entrypoint (Akash & any container runtime)
# -----------------------------------------------------------------------------
# Authenticates to Vault with the 'akash-runtime' AppRole, pulls the runtime
# secrets, exports them as environment variables, then exec's the workload.
#
# NOTHING is hardcoded. The container ships with zero secrets baked in; all
# sensitive material is fetched at boot and lives only in process memory.
#
# Required environment (injected by the Akash SDL / orchestrator at deploy):
#   VAULT_ADDR      Vault API address (https://...)
#   VAULT_ROLE_ID   Role ID of the 'akash-runtime' AppRole (not secret)
# Secret ID — provide exactly ONE of:
#   VAULT_SECRET_ID_WRAPPING_TOKEN   response-wrapped secret_id (PREFERRED)
#   VAULT_SECRET_ID                  raw secret_id (fallback)
# Optional:
#   VAULT_KV_MOUNT          KV mount (default: kv)
#   VAULT_NAMESPACE         Vault namespace (Enterprise/HCP)
#   VAULT_CACERT            path to a CA bundle for TLS verification
#   VAULT_SECRET_PATHS      space-separated KV paths to load
#                           (default: yieldswarm/app/core yieldswarm/app/llm
#                                     yieldswarm/rpc/solana)
# =============================================================================
set -euo pipefail
umask 077

log() { printf '\033[1;34m[entrypoint]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[entrypoint:error]\033[0m %s\n' "$*" >&2; exit 1; }

KV_MOUNT="${VAULT_KV_MOUNT:-kv}"
SECRET_PATHS="${VAULT_SECRET_PATHS:-yieldswarm/app/core yieldswarm/app/llm yieldswarm/rpc/solana}"
CURL_OPTS=(--fail --silent --show-error --max-time 15)

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID must be set}"
command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
command -v jq   >/dev/null 2>&1 || die "jq is required but not installed"

# Namespace + TLS verification headers/options.
NS_HEADER=()
[ -n "${VAULT_NAMESPACE:-}" ] && NS_HEADER=(-H "X-Vault-Namespace: ${VAULT_NAMESPACE}")
[ -n "${VAULT_CACERT:-}" ] && CURL_OPTS+=(--cacert "${VAULT_CACERT}")

vault_api() {
  # vault_api <http-method> <path> [json-body]
  local method="$1" path="$2" body="${3:-}"
  local args=("${CURL_OPTS[@]}" -X "${method}" "${NS_HEADER[@]}" \
    -H "X-Vault-Request: true" "${VAULT_ADDR}/v1/${path}")
  [ -n "${TOKEN:-}" ] && args+=(-H "X-Vault-Token: ${TOKEN}")
  if [ -n "${body}" ]; then
    args+=(-H "Content-Type: application/json" -d "${body}")
  fi
  curl "${args[@]}"
}

# --- 1. Resolve the secret_id (unwrap if a wrapping token was provided) -----
SECRET_ID=""
TOKEN=""
if [ -n "${VAULT_SECRET_ID_WRAPPING_TOKEN:-}" ]; then
  log "Unwrapping response-wrapped secret_id"
  TOKEN="${VAULT_SECRET_ID_WRAPPING_TOKEN}"
  unwrap_resp="$(vault_api POST "sys/wrapping/unwrap")" \
    || die "failed to unwrap secret_id (token expired or already used?)"
  TOKEN=""
  SECRET_ID="$(printf '%s' "${unwrap_resp}" | jq -r '.data.secret_id // empty')"
  [ -n "${SECRET_ID}" ] || die "unwrapped payload did not contain a secret_id"
  unset VAULT_SECRET_ID_WRAPPING_TOKEN unwrap_resp
elif [ -n "${VAULT_SECRET_ID:-}" ]; then
  SECRET_ID="${VAULT_SECRET_ID}"
  unset VAULT_SECRET_ID
else
  die "provide VAULT_SECRET_ID_WRAPPING_TOKEN (preferred) or VAULT_SECRET_ID"
fi

# --- 2. AppRole login -> client token ---------------------------------------
log "Authenticating to Vault via AppRole"
login_body="$(jq -nc --arg r "${VAULT_ROLE_ID}" --arg s "${SECRET_ID}" \
  '{role_id:$r, secret_id:$s}')"
login_resp="$(vault_api POST "auth/approle/login" "${login_body}")" \
  || die "AppRole login failed"
unset SECRET_ID login_body
TOKEN="$(printf '%s' "${login_resp}" | jq -r '.auth.client_token // empty')"
unset login_resp
[ -n "${TOKEN}" ] || die "no client_token returned from AppRole login"

# --- 3. Pull secrets and export as environment variables --------------------
load_path() {
  local path="$1" resp keys k v envname
  log "Loading kv/${path}"
  resp="$(vault_api GET "${KV_MOUNT}/data/${path}")" \
    || die "could not read ${KV_MOUNT}/data/${path} (policy/path mismatch?)"
  keys="$(printf '%s' "${resp}" | jq -r '.data.data | keys[]')"
  for k in ${keys}; do
    v="$(printf '%s' "${resp}" | jq -r --arg k "${k}" '.data.data[$k]')"
    [ "${v}" = "null" ] && continue
    envname="$(printf '%s' "${k}" | tr '[:lower:]' '[:upper:]')"
    export "${envname}=${v}"
  done
  unset resp
}

loaded=0
for p in ${SECRET_PATHS}; do
  load_path "${p}"
  loaded=$((loaded + 1))
done
log "Loaded secrets from ${loaded} path(s). Revoking bootstrap token."

# --- 4. Best-effort token cleanup; secrets remain in this process' env ------
vault_api POST "auth/token/revoke-self" >/dev/null 2>&1 || true
unset TOKEN

# --- 5. Hand off to the workload (PID 1 via exec) ---------------------------
if [ "$#" -eq 0 ]; then
  die "no command supplied to run after secret injection"
fi
log "Secrets injected into environment. Starting: $*"
exec "$@"

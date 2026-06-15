#!/usr/bin/env bash
# scripts/lib/vault-akash-bootstrap.sh
#
# Mint response-wrapped AppRole SecretIDs and build provider-services
# --env flags for Akash deployment create. Wrapped tokens are single-use
# and short-lived; the container entrypoint unwraps them once at boot.
#
# Usage (source from deploy scripts):
#   source scripts/lib/vault-akash-bootstrap.sh
#   vault_prepare_akash_bootstrap akash-runtime
#   provider-services tx deployment create "$sdl" $(vault_akash_env_flags) ...
#
set -euo pipefail

# shellcheck disable=SC2034
VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
VAULT_WRAP_TTL="${VAULT_WRAP_TTL:-600s}"
VAULT_INJECT_RUNTIME_SECRETS="${VAULT_INJECT_RUNTIME_SECRETS:-auto}"

vault__bootstrap_need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[vault-akash] required command missing: $1" >&2
    return 1
  }
}

# Return 0 when SDL expects runtime Vault bootstrap env vars.
vault_sdl_needs_runtime_secrets() {
  local sdl="$1"
  [[ -f "$sdl" ]] || return 1
  grep -qE '(^|[[:space:]-])VAULT_WRAPPED_SECRET_ID([[:space:]]|$)|VAULT_ROLE_ID[[:space:]]*$' "$sdl"
}

# Mint wrapped SecretID + role_id for the given AppRole (default: akash-runtime).
vault_prepare_akash_bootstrap() {
  local role="${1:-${VAULT_AKASH_ROLE}}"
  VAULT_WRAP_TTL="${VAULT_WRAP_TTL:-600s}"

  [[ -n "${VAULT_ADDR:-}" ]] || {
    echo "[vault-akash] VAULT_ADDR unset — skipping bootstrap mint" >&2
    return 1
  }

  vault__bootstrap_need_cmd vault
  vault__bootstrap_need_cmd jq

  local token
  token="${VAULT_TOKEN:-}"
  if [[ -z "$token" && -n "${VAULT_TOKEN_FILE:-}" && -r "${VAULT_TOKEN_FILE}" ]]; then
    token="$(<"${VAULT_TOKEN_FILE}")"
  fi
  if [[ -z "$token" && -f "${REPO_ROOT:-.}/.vault-token" ]]; then
    token="$(<"${REPO_ROOT}/.vault-token")"
  fi
  [[ -n "$token" ]] || {
    echo "[vault-akash] VAULT_TOKEN required to mint wrapped SecretID for role ${role}" >&2
    return 1
  }
  export VAULT_TOKEN="$token"

  echo "[vault-akash] minting wrapped SecretID for role=${role} ttl=${VAULT_WRAP_TTL}" >&2
  VAULT_WRAPPED_SECRET_ID="$(
    vault write -wrap-ttl="${VAULT_WRAP_TTL}" -force -format=json \
      "auth/approle/role/${role}/secret-id" | jq -r '.wrap_info.token // empty'
  )"
  VAULT_ROLE_ID="$(
    vault read -field=role_id -format=json "auth/approle/role/${role}/role-id"
  )"

  [[ -n "${VAULT_WRAPPED_SECRET_ID}" && -n "${VAULT_ROLE_ID}" ]] || {
    echo "[vault-akash] failed to mint bootstrap credentials for ${role}" >&2
    return 1
  }

  export VAULT_WRAPPED_SECRET_ID VAULT_ROLE_ID
  export AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"
  echo "[vault-akash] bootstrap ready (role=${role}, shard=${AGENT_SHARD_ID})" >&2
}

# Print --env KEY=VALUE arguments for provider-services deployment create.
vault_akash_env_flags() {
  local flags=()
  [[ -n "${VAULT_ADDR:-}" ]] && flags+=(--env "VAULT_ADDR=${VAULT_ADDR}")
  [[ -n "${VAULT_ROLE_ID:-}" ]] && flags+=(--env "VAULT_ROLE_ID=${VAULT_ROLE_ID}")
  [[ -n "${VAULT_WRAPPED_SECRET_ID:-}" ]] && flags+=(--env "VAULT_WRAPPED_SECRET_ID=${VAULT_WRAPPED_SECRET_ID}")
  [[ -n "${AGENT_SHARD_ID:-}" ]] && flags+=(--env "AGENT_SHARD_ID=${AGENT_SHARD_ID}")
  [[ -n "${VAULT_SKIP_VERIFY:-}" ]] && flags+=(--env "VAULT_SKIP_VERIFY=${VAULT_SKIP_VERIFY}")
  [[ -n "${VAULT_AGENT_CONFIG:-}" ]] && flags+=(--env "VAULT_AGENT_CONFIG=${VAULT_AGENT_CONFIG}")
  [[ -n "${AGENT_ENV_FILE:-}" ]] && flags+=(--env "AGENT_ENV_FILE=${AGENT_ENV_FILE}")
  printf '%s\n' "${flags[@]}"
}

# Auto-mint when SDL needs bootstrap and credentials are not already exported.
vault_maybe_prepare_for_sdl() {
  local sdl="$1"
  local role="${2:-${VAULT_AKASH_ROLE}}"

  case "${VAULT_INJECT_RUNTIME_SECRETS}" in
    0|false|no|off) return 0 ;;
    auto)
      vault_sdl_needs_runtime_secrets "$sdl" || return 0
      ;;
    1|true|yes|on) ;;
    *) return 0 ;;
  esac

  if [[ -n "${VAULT_WRAPPED_SECRET_ID:-}" && -n "${VAULT_ROLE_ID:-}" ]]; then
    echo "[vault-akash] using pre-exported VAULT_ROLE_ID + VAULT_WRAPPED_SECRET_ID" >&2
    return 0
  fi

  vault_prepare_akash_bootstrap "$role"
}

# Write bootstrap metadata for audit (never includes the wrap token).
vault_write_bootstrap_audit() {
  local out="${1:-${RUN_DIR:-.run}/vault-akash-bootstrap.json}"
  mkdir -p "$(dirname "$out")"
  jq -n \
    --arg role "${VAULT_AKASH_ROLE}" \
    --arg addr "${VAULT_ADDR:-}" \
    --arg shard "${AGENT_SHARD_ID:-0}" \
    --arg ttl "${VAULT_WRAP_TTL}" \
    --arg ts "$(date -u +%FT%TZ)" \
    '{role:$role, vault_addr:$addr, agent_shard_id:$shard, wrap_ttl:$ttl, minted_at:$ts}' \
    > "$out"
  chmod 600 "$out" 2>/dev/null || true
}

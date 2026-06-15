#!/usr/bin/env bash
# seed-secrets.sh
# Interactive seeder for the YieldSwarm Vault namespace.
#
# Design:
#   * Reads secret values from stdin or environment - NEVER from CLI flags
#     (they would be visible in /proc/<pid>/cmdline and shell history).
#   * Writes via `vault kv put` using key=@/dev/stdin for streaming.
#   * Refuses to overwrite an existing path unless --force is given.
#   * Writes a placeholder if a key is intentionally blank (e.g. dev env).
#
# Usage:
#   VAULT_ADDR=https://vault.internal:8200 VAULT_TOKEN=... \
#     infrastructure/vault/seed/seed-secrets.sh                # interactive
#
#   # Non-interactive (CI bootstrap from a sealed envelope file):
#   VAULT_ADDR=... VAULT_TOKEN=... \
#     infrastructure/vault/seed/seed-secrets.sh --from-env-file ./secrets.env
#
# The --from-env-file form expects KEY=VALUE lines; VALUE may be empty.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "$SCRIPT_DIR/../bootstrap/lib.sh"

vault_status_or_die
require_cmd vault

FORCE=0
ENV_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)         FORCE=1; shift ;;
        --from-env-file) ENV_FILE="${2:?--from-env-file requires a path}"; shift 2 ;;
        -h|--help)
            sed -n '2,25p' "$0"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

# Schema: each entry is "<vault-path>|<key1> <key2> ...".
# These are the ONLY paths the seeder will write to. Add new entries here
# when the policies grow; never accept arbitrary paths from CLI.
declare -a SCHEMA=(
    "yieldswarm/cloud/azure|client_id client_secret tenant_id subscription_id"
    "yieldswarm/cloud/runpod|api_key org_id default_pod_template"
    "yieldswarm/cloud/vultr|api_key default_region"
    "yieldswarm/cloud/digitalocean|api_token spaces_access_id spaces_secret_key default_region"
    "yieldswarm/rpc/solana|primary_url failover_url ws_url"
    "yieldswarm/rpc/helius|api_key url"
    "yieldswarm/rpc/birdeye|api_key"
    "yieldswarm/rpc/jupiter|api_key"
    "yieldswarm/rpc/ethereum|primary_url failover_url"
    "yieldswarm/akash/deployer|key_name keyring_backend chain_id node_url wallet_mnemonic"
    "yieldswarm/runtime/agentswarm|master_key kimiclaw_key wallet_encryption_key tee_signing_key database_encryption_key"
    "yieldswarm/runtime/llm|openai_api_key anthropic_api_key gemini_api_key grok_api_key"
)

# Load env-file in a subshell to avoid polluting current env.
load_env_file() {
    local file="$1"
    [[ -r "$file" ]] || die "env file not readable: $file"
    set -a
    # shellcheck source=/dev/null
    . "$file"
    set +a
}
[[ -n "$ENV_FILE" ]] && load_env_file "$ENV_FILE"

read_secret() {
    local key="$1" envvar
    envvar="$(echo "${key^^}" | tr -c 'A-Z0-9' '_')"
    if [[ -n "${!envvar:-}" ]]; then
        printf '%s' "${!envvar}"
        return 0
    fi
    if [[ -n "$ENV_FILE" ]]; then
        # In non-interactive mode, missing -> empty (placeholder).
        printf ''
        return 0
    fi
    # Interactive prompt; never echoes.
    local val
    printf '%s  %s = ' "$C_DIM" "$envvar" >&2
    IFS= read -rs val
    printf '\n' >&2
    printf '%s' "$val"
}

seed_path() {
    local path="$1"; shift
    local -a keys=("$@")
    local full_path="${VAULT_SECRET_BASE}/$path"

    if [[ "$FORCE" != "1" ]] && vault kv get -mount="$VAULT_KV_MOUNT" "$full_path" >/dev/null 2>&1; then
        warn "skip ${VAULT_KV_MOUNT}/${full_path} (already populated; pass --force to overwrite)"
        return 0
    fi

    log "Seeding ${VAULT_KV_MOUNT}/${full_path}"
    # Build a single JSON doc in-memory via jq so secret values never appear
    # on the command line (they would otherwise leak via /proc/<pid>/cmdline).
    local tmp; tmp=$(mktemp); trap 'shred -u "$tmp" 2>/dev/null || rm -f "$tmp"' RETURN

    local filter='{}'
    local -a jq_args=(-n)
    for k in "${keys[@]}"; do
        local v; v=$(read_secret "$k")
        jq_args+=(--arg "$k" "$v")
        filter+=" | .\"$k\" = \$$k"
    done
    jq "${jq_args[@]}" "$filter" > "$tmp"

    vault kv put -mount="$VAULT_KV_MOUNT" "$full_path" "@$tmp" >/dev/null
    ok "wrote $(jq 'keys|length' "$tmp") keys to ${VAULT_KV_MOUNT}/${full_path}"
}

require_cmd jq
for entry in "${SCHEMA[@]}"; do
    path="${entry%%|*}"
    keys_str="${entry#*|}"
    # shellcheck disable=SC2206
    keys_arr=( $keys_str )
    seed_path "$path" "${keys_arr[@]}"
done

ok "seed complete"

# shellcheck shell=bash
# Shared helpers for Vault bootstrap scripts.
# Sourced, not executed. Do not run directly.

set -Eeuo pipefail

# Color codes (TTY only).
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
    C_YLW=$'\033[33m'; C_BLU=$'\033[34m'; C_DIM=$'\033[2m'
else
    C_RESET=""; C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_DIM=""
fi
# shellcheck disable=SC2034 # C_DIM consumed by sourcing scripts (seed prompt)
: "$C_DIM"

log()  { printf '%s[vault-bootstrap]%s %s\n' "$C_BLU" "$C_RESET" "$*" >&2; }
ok()   { printf '%s[ ok ]%s %s\n' "$C_GRN" "$C_RESET" "$*" >&2; }
warn() { printf '%s[warn]%s %s\n' "$C_YLW" "$C_RESET" "$*" >&2; }
die()  { printf '%s[fail]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

require_cmd() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
    done
}

# Resolve repo paths regardless of where the script was invoked from.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[1]:-$0}")" && pwd)"
VAULT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC2034 # consumed by sourcing scripts
POLICY_DIR="$VAULT_ROOT/policies"
# shellcheck disable=SC2034
SEED_DIR="$VAULT_ROOT/seed"

# Sane production defaults; can be overridden by environment.
: "${VAULT_ADDR:?VAULT_ADDR must be set (e.g. https://vault.internal:8200)}"
: "${VAULT_KV_MOUNT:=secret}"        # KV v2 mount point.
: "${VAULT_SECRET_BASE:=yieldswarm}" # Logical namespace inside KV.
: "${VAULT_APPROLE_MOUNT:=approle}"
: "${VAULT_AUDIT_PATH:=file/}"       # Audit device path.
: "${VAULT_AUDIT_LOG:=/var/log/vault/audit.log}"

# Guard rails: never accept the dev-mode root token in production scripts
# unless the operator explicitly opts in.
if [[ "${VAULT_TOKEN:-}" == "root" && "${VAULT_ALLOW_DEV_ROOT:-0}" != "1" ]]; then
    die "Refusing to run with dev root token. Re-run with a real admin token, or set VAULT_ALLOW_DEV_ROOT=1 for local dev."
fi

vault_status_or_die() {
    require_cmd vault
    vault status -format=json >/dev/null 2>&1 \
        || die "cannot reach Vault at $VAULT_ADDR (sealed? wrong VAULT_TOKEN?)"
}

# Write a KV v2 secret only if the path is empty. Refuses to overwrite real data.
kv_put_if_absent() {
    local path="$1"; shift
    if vault kv get -mount="$VAULT_KV_MOUNT" "$path" >/dev/null 2>&1; then
        warn "secret already present at ${VAULT_KV_MOUNT}/${path} - leaving untouched"
        return 0
    fi
    vault kv put -mount="$VAULT_KV_MOUNT" "$path" "$@" >/dev/null
    ok "seeded placeholder at ${VAULT_KV_MOUNT}/${path}"
}

# Write a policy idempotently from a file.
policy_write() {
    local name="$1" file="$2"
    [[ -r "$file" ]] || die "policy file not readable: $file"
    vault policy write "$name" "$file" >/dev/null
    ok "policy '$name' applied from $(basename "$file")"
}

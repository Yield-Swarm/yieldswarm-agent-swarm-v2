#!/usr/bin/env bash
# 01-engines.sh
# Enable the secrets engines and audit device required by the YieldSwarm stack.
# Idempotent: safe to re-run after upgrades.

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

vault_status_or_die

ensure_mount() {
    local path="$1" type="$2" description="$3" extra="${4:-}"
    if vault secrets list -format=json | jq -e --arg p "${path%/}/" 'has($p)' >/dev/null; then
        ok "secrets engine '$path' already enabled"
        return 0
    fi
    # shellcheck disable=SC2086
    vault secrets enable -path="$path" -description="$description" $extra "$type" >/dev/null
    ok "enabled $type at '$path'"
}

ensure_auth() {
    local path="$1" type="$2"
    if vault auth list -format=json | jq -e --arg p "${path%/}/" 'has($p)' >/dev/null; then
        ok "auth method '$path' already enabled"
        return 0
    fi
    vault auth enable -path="$path" "$type" >/dev/null
    ok "enabled auth method $type at '$path'"
}

ensure_audit() {
    if vault audit list -format=json 2>/dev/null | jq -e --arg p "$VAULT_AUDIT_PATH" 'has($p)' >/dev/null; then
        ok "audit device '$VAULT_AUDIT_PATH' already enabled"
        return 0
    fi
    install -d -m 0750 "$(dirname "$VAULT_AUDIT_LOG")" 2>/dev/null || true
    vault audit enable -path="$VAULT_AUDIT_PATH" file \
        file_path="$VAULT_AUDIT_LOG" \
        log_raw=false \
        hmac_accessor=true >/dev/null
    ok "enabled file audit device at $VAULT_AUDIT_LOG"
}

require_cmd jq

log "Configuring secrets engines on $VAULT_ADDR"

ensure_mount "$VAULT_KV_MOUNT" kv-v2 "YieldSwarm KV v2 store" "-version=2"
ensure_mount transit transit "Application-layer envelope encryption"
ensure_mount sys/transform transform "PII tokenization (FF1/FPE)" || true

ensure_auth "$VAULT_APPROLE_MOUNT" approle

ensure_audit

# Provision long-lived application keys for transit envelope encryption.
ensure_transit_key() {
    local key="$1"
    if vault read "transit/keys/$key" >/dev/null 2>&1; then
        ok "transit key '$key' already exists"
    else
        vault write -f "transit/keys/$key" type=aes256-gcm96 >/dev/null
        ok "created transit key '$key'"
    fi
}
ensure_transit_key yieldswarm-app
ensure_transit_key yieldswarm-wallets

ok "secrets engines provisioned"

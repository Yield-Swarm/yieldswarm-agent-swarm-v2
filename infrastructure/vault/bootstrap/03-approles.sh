#!/usr/bin/env bash
# 03-approles.sh
# Create AppRoles for Terraform and the Akash workload. Hardened defaults:
#   * secret_id_ttl  : 24h    (rotate daily via CI / out-of-band)
#   * token_ttl      : 30m    (short-lived; client must renew)
#   * token_max_ttl  : 2h     (hard cap)
#   * secret_id_num_uses : 0  (unlimited within ttl, since CI re-mints)
#   * secret_id_bound_cidrs : configurable per role
#
# Outputs the role_id (safe to ship to CI) on stdout. The secret_id is
# response-wrapped with a 60s wrapping TTL and printed once - never logged.

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

vault_status_or_die
require_cmd jq

upsert_role() {
    local role="$1" policy="$2" cidrs="$3" extra_args="${4:-}"
    local path="auth/${VAULT_APPROLE_MOUNT%/}/role/${role}"

    # shellcheck disable=SC2086
    vault write "$path" \
        token_policies="$policy" \
        token_ttl=30m \
        token_max_ttl=2h \
        token_num_uses=0 \
        token_no_default_policy=true \
        secret_id_ttl=24h \
        secret_id_num_uses=0 \
        secret_id_bound_cidrs="$cidrs" \
        token_bound_cidrs="$cidrs" \
        $extra_args >/dev/null

    local role_id
    role_id=$(vault read -field=role_id "$path/role-id")
    ok "AppRole '$role' configured (cidrs=$cidrs)"
    printf 'ROLE_ID[%s]=%s\n' "$role" "$role_id"
}

# CIDR allow-lists. Override via env to match your runner / Akash provider egress.
: "${TERRAFORM_CIDR:=0.0.0.0/0}"
: "${AKASH_CIDR:=0.0.0.0/0}"

if [[ "$TERRAFORM_CIDR" == "0.0.0.0/0" ]]; then
    warn "TERRAFORM_CIDR is 0.0.0.0/0 - acceptable for first bootstrap, tighten before production"
fi
if [[ "$AKASH_CIDR" == "0.0.0.0/0" ]]; then
    warn "AKASH_CIDR is 0.0.0.0/0 - tighten to your Akash provider egress range before production"
fi

log "Upserting AppRoles"
upsert_role terraform-deployer terraform-deployer "$TERRAFORM_CIDR"
upsert_role akash-workload      akash-workload    "$AKASH_CIDR"

# Optional: mint a one-shot wrapped secret_id for immediate use.
if [[ "${MINT_WRAPPED_SECRET_IDS:-0}" == "1" ]]; then
    log "Minting response-wrapped secret_ids (TTL 60s, single-use)"
    for role in terraform-deployer akash-workload; do
        wrap_token=$(vault write -wrap-ttl=60s -force -field=wrapping_token \
            "auth/${VAULT_APPROLE_MOUNT%/}/role/${role}/secret-id")
        printf 'WRAP_TOKEN[%s]=%s\n' "$role" "$wrap_token"
        warn "Hand $role wrap token to operator immediately - it expires in 60s and is single-use."
    done
fi

ok "AppRoles ready"

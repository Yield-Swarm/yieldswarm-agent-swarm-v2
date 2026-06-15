#!/usr/bin/env bash
# =============================================================================
# 20-approles.sh
# -----------------------------------------------------------------------------
# Provision AppRoles for every non-human principal that talks to Vault:
#
#   * terraform-deploy   <-- the CI runner that applies infrastructure
#   * akash-runtime      <-- workloads inside Akash containers
#   * ci-pipeline        <-- GitHub Actions / Vercel build hooks
#   * secrets-rotator    <-- the 15-minute rotation cron
#
# After provisioning, this script writes the role_id to stdout and (if
# $WRAP_SECRET_ID is set to "true") emits a response-wrapped secret_id. The
# wrapped token has a 5-minute TTL: callers MUST unwrap immediately.
#
# Output format (one role per line):
#   <role_name> role_id=<uuid> secret_id_wrapping_token=<token-or-PLAIN>
# =============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

WRAP_SECRET_ID="${WRAP_SECRET_ID:-true}"

log() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*" >&2; }

# role_name | policies | token_ttl | token_max_ttl | secret_id_ttl | token_num_uses | bind_cidrs
ROLES=(
  "terraform-deploy|terraform-deploy|1h|24h|24h|0|"
  "akash-runtime|akash-runtime|24h|720h|0|0|"
  "ci-pipeline|ci-pipeline|30m|2h|2h|0|"
  "secrets-rotator|secrets-rotator|15m|1h|1h|0|"
)

emit() {
  printf '%s role_id=%s secret_id_wrapping_token=%s\n' "$1" "$2" "$3"
}

for spec in "${ROLES[@]}"; do
  IFS='|' read -r name policy ttl max_ttl sid_ttl num_uses cidrs <<<"$spec"

  log "Configuring AppRole ${name}"
  vault write "auth/approle/role/${name}" \
    token_policies="${policy},default" \
    token_ttl="${ttl}" \
    token_max_ttl="${max_ttl}" \
    secret_id_ttl="${sid_ttl}" \
    token_num_uses="${num_uses}" \
    secret_id_num_uses=0 \
    bind_secret_id=true \
    ${cidrs:+secret_id_bound_cidrs="${cidrs}"} \
    ${cidrs:+token_bound_cidrs="${cidrs}"} \
    >/dev/null

  role_id="$(vault read -field=role_id "auth/approle/role/${name}/role-id")"

  if [[ "$WRAP_SECRET_ID" == "true" ]]; then
    wrap_token="$(
      VAULT_WRAP_TTL=300s vault write -f -field=wrapping_token \
        "auth/approle/role/${name}/secret-id"
    )"
    emit "$name" "$role_id" "$wrap_token"
  else
    secret_id="$(vault write -f -field=secret_id "auth/approle/role/${name}/secret-id")"
    emit "$name" "$role_id" "PLAIN:${secret_id}"
  fi
done

log "AppRoles ready. Delivery channels: see SECRETS.md (response-wrapping)."

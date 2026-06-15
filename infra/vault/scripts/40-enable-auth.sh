#!/usr/bin/env bash
# 40-enable-auth.sh
# Create AppRole roles for terraform-cicd, akash-runtime, agent-readonly.
# Emits a response-wrapped secret_id for each consumer (TTL configurable).
#
# Outputs are written to ${APPROLE_OUT_DIR:-/run/secrets/approle} with mode 0400.
# Operators must move these wrapped tokens to the consumer immediately;
# unwrapping is single-use and the token expires after WRAP_TTL.

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
vault_check
require_env VAULT_TOKEN

WRAP_TTL="${WRAP_TTL:-300s}"           # 5 minutes to ship the secret_id
OUT_DIR="${APPROLE_OUT_DIR:-/run/secrets/approle}"
install -d -m 0700 "$OUT_DIR"

create_role() {
  local name="$1" policy="$2" ttl="$3" max_ttl="$4" period="${5:-}"
  log "configuring approle: $name (policy=$policy ttl=$ttl max_ttl=$max_ttl period=${period:-none})"

  local args=(
    "auth/approle/role/$name"
    token_policies="$policy"
    token_ttl="$ttl"
    token_max_ttl="$max_ttl"
    secret_id_ttl=0
    secret_id_num_uses=1
    bind_secret_id=true
    token_no_default_policy=true
    token_type=service
  )
  [[ -n "$period" ]] && args+=( token_period="$period" )
  vault write "${args[@]}" >/dev/null

  local role_id
  role_id="$(vault read -field=role_id "auth/approle/role/$name/role-id")"
  printf '%s' "$role_id" > "$OUT_DIR/${name}.role_id"
  chmod 0400 "$OUT_DIR/${name}.role_id"
  log "  role_id -> $OUT_DIR/${name}.role_id"

  log "  issuing response-wrapped secret_id (wrap_ttl=$WRAP_TTL)"
  VAULT_WRAP_TTL="$WRAP_TTL" \
    vault write -wrap-ttl="$WRAP_TTL" -format=json \
      -f "auth/approle/role/$name/secret-id" \
      | jq -r .wrap_info.token > "$OUT_DIR/${name}.secret_id.wrapped"
  chmod 0400 "$OUT_DIR/${name}.secret_id.wrapped"
  log "  wrapped secret_id -> $OUT_DIR/${name}.secret_id.wrapped"
}

# CI/CD - short TTL, max 1h.  Tokens are one-shot per pipeline run.
create_role terraform-cicd terraform-cicd 30m 1h

# Akash workload - periodic so Vault Agent can renew indefinitely
# while the deployment is alive.
create_role akash-runtime akash-runtime 1h 24h 1h

# Internal agents - similar pattern.
create_role agent-readonly agent-readonly 1h 24h 1h

log ""
log "ship the .wrapped files to the consumers OUT OF BAND immediately."
log "they have ${WRAP_TTL} to unwrap before they self-destruct."

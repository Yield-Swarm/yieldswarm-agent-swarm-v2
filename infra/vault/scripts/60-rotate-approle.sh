#!/usr/bin/env bash
# 60-rotate-approle.sh
# Rotate the secret_id for a single AppRole.  Use on a schedule (e.g. weekly
# cron) or after any suspected compromise.  Existing tokens issued under the
# old secret_id remain valid until their TTL expires; revoke them explicitly
# with `vault token revoke -accessor ...` if needed.

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
vault_check
require_env VAULT_TOKEN

role="${1:-}"
[[ -n "$role" ]] || die "usage: $0 <approle-name>"

WRAP_TTL="${WRAP_TTL:-300s}"
OUT_DIR="${APPROLE_OUT_DIR:-/run/secrets/approle}"
install -d -m 0700 "$OUT_DIR"

log "rotating secret_id for approle: $role"
vault write -wrap-ttl="$WRAP_TTL" -format=json \
  -f "auth/approle/role/$role/secret-id" \
  | jq -r .wrap_info.token > "$OUT_DIR/${role}.secret_id.wrapped"
chmod 0400 "$OUT_DIR/${role}.secret_id.wrapped"

log "new wrapped secret_id -> $OUT_DIR/${role}.secret_id.wrapped (ttl=$WRAP_TTL)"
log "ship out-of-band; old secret_id remains until TTL or explicit destroy"

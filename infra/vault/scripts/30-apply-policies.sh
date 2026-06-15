#!/usr/bin/env bash
# 30-apply-policies.sh
# Push every policy in policies/*.hcl into Vault.  Idempotent (write is upsert).

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
vault_check
require_env VAULT_TOKEN

shopt -s nullglob
for f in "${VAULT_DIR}/policies"/*.hcl; do
  name="$(basename "$f" .hcl)"
  log "applying policy: $name  <-  ${f#"$REPO_ROOT"/}"
  vault policy write "$name" "$f"
done
log "policies applied"

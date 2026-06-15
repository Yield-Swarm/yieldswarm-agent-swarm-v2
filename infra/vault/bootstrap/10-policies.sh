#!/usr/bin/env bash
# =============================================================================
# 10-policies.sh
# -----------------------------------------------------------------------------
# Upload every .hcl policy file under ../policies/ to Vault. Policy name ==
# file name minus the .hcl suffix. Idempotent: vault policy write replaces.
# =============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${HERE}/../policies"

log() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }

if [[ ! -d "$POLICY_DIR" ]]; then
  echo "policy dir not found: $POLICY_DIR" >&2
  exit 1
fi

shopt -s nullglob
for f in "$POLICY_DIR"/*.hcl; do
  name="$(basename "$f" .hcl)"
  log "Writing policy: ${name}"
  vault policy write "$name" "$f"
done

log "All policies installed:"
vault policy list

#!/usr/bin/env bash
# vault/setup/03-write-policies.sh
#
# Push every policy in vault/policies/*.hcl into Vault. Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib.sh"
require_token

POLICY_DIR="${HERE}/../policies"
[ -d "${POLICY_DIR}" ] || die "policy dir not found: ${POLICY_DIR}"

shopt -s nullglob
for f in "${POLICY_DIR}"/*.hcl; do
  name="$(basename "$f" .hcl)"
  ensure_policy "${name}" "$f"
done

log "Loaded policies:"
vault policy list

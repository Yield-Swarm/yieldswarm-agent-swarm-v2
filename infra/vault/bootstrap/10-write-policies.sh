#!/usr/bin/env bash
# Upload the apn-* Vault policies from infra/vault/policies/.
#
# Idempotent: re-running the script overwrites the policy with the
# version currently checked into the repo. Treat the HCL files as the
# source of truth and never edit policies in the Vault UI.

set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$(cd "${SCRIPT_DIR}/../policies" && pwd)"

log() { printf '[bootstrap] %s\n' "$*"; }

for policy_file in "${POLICY_DIR}"/apn-*.hcl; do
  policy_name="$(basename "${policy_file}" .hcl)"
  log "writing policy ${policy_name} from ${policy_file}"
  vault policy write "${policy_name}" "${policy_file}"
done

log "policies in Vault:"
vault policy list | grep '^apn-' || true

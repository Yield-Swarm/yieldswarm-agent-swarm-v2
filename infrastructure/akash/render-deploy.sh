#!/usr/bin/env bash
# =============================================================================
# Render the Akash SDL with fresh Vault credentials. The rendered file is
# written to a path of your choice (default /tmp/akash-deploy-XXXXXX.yaml)
# and printed on stdout. Pipe to `akash tx deployment create`.
#
# Requires:
#   * VAULT_ADDR, VAULT_TOKEN exported (operator with secrets-admin policy
#     or any policy that can issue secret-ids on yieldswarm-akash)
#   * `vault`, `envsubst`, `mktemp` on PATH
# =============================================================================

set -euo pipefail

SDL_SRC="${SDL_SRC:-$(dirname "$0")/deploy.yaml}"
OUT="${OUT:-$(mktemp -t akash-deploy-XXXXXX.yaml)}"

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set (issue secret-ids for yieldswarm-akash)}"

export VAULT_ADDR
export VAULT_ROLE_ID
export VAULT_WRAPPING_TOKEN

VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/yieldswarm-akash/role-id)"
VAULT_WRAPPING_TOKEN="$(
  VAULT_WRAP_TTL=300 vault write -f -field=wrapping_token \
    auth/approle/role/yieldswarm-akash/secret-id
)"

envsubst '${VAULT_ADDR} ${VAULT_ROLE_ID} ${VAULT_WRAPPING_TOKEN}' \
  < "${SDL_SRC}" > "${OUT}"
chmod 600 "${OUT}"

printf '\n[render] wrote %s\n' "${OUT}" >&2
printf '[render] expire-on-unwrap secret_id is single-use; deploy now or rerun.\n' >&2
printf '%s\n' "${OUT}"

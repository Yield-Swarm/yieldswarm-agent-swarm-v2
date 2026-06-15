#!/usr/bin/env bash
# tf-with-vault.sh
# Wrapper that obtains a fresh, short-lived AppRole secret_id for the
# terraform-deployer role and execs `terraform` with it injected via env
# vars. The secret_id never appears on a command line or in shell history.
#
# Modes (auto-detected):
#   * If WRAPPED_SECRET_ID is set, unwrap it (single-use, expires fast)
#     and use the result. The caller is responsible for handing us a
#     fresh wrapping token (e.g. from a privileged orchestrator).
#   * Otherwise, VAULT_TOKEN must have the ci-pipeline policy; we mint a
#     new secret_id directly.
#
# Required env: VAULT_ADDR.
# Optional env: VAULT_NAMESPACE, TF_VAULT_ROLE_NAME (default terraform-deployer),
#               TF_VAULT_APPROLE_MOUNT (default approle).

set -Eeuo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"

command -v vault     >/dev/null || { echo "vault binary not found" >&2; exit 1; }
command -v terraform >/dev/null || { echo "terraform binary not found" >&2; exit 1; }

ROLE_NAME="${TF_VAULT_ROLE_NAME:-terraform-deployer}"
APPROLE_MOUNT="${TF_VAULT_APPROLE_MOUNT:-approle}"
ROLE_PATH="auth/${APPROLE_MOUNT}/role/${ROLE_NAME}"

# 1. Obtain the role_id (safe to log, useless on its own).
ROLE_ID=$(vault read -field=role_id "${ROLE_PATH}/role-id")

# 2. Obtain the secret_id - either by unwrapping a handoff token or by
#    minting one ourselves with a ci-pipeline token.
if [[ -n "${WRAPPED_SECRET_ID:-}" ]]; then
    SECRET_ID=$(VAULT_TOKEN="$WRAPPED_SECRET_ID" \
        vault unwrap -field=secret_id)
    unset WRAPPED_SECRET_ID
else
    : "${VAULT_TOKEN:?VAULT_TOKEN or WRAPPED_SECRET_ID must be set}"
    SECRET_ID=$(vault write -force -field=secret_id "${ROLE_PATH}/secret-id")
fi

# 3. Hand the credentials to Terraform via TF_VAR_ env vars. These are
#    inherited only by the terraform child process; no `set -x` and no
#    `env` dump should ever land in CI logs (the wrapper enforces this).
export TF_VAR_vault_auth_role_id="$ROLE_ID"
export TF_VAR_vault_auth_secret_id="$SECRET_ID"
export TF_VAR_vault_address="$VAULT_ADDR"
[[ -n "${VAULT_NAMESPACE:-}" ]] && export TF_VAR_vault_namespace="$VAULT_NAMESPACE"

# 4. Drop our own privileged token so Terraform cannot accidentally use
#    it (e.g. via VAULT_TOKEN in the env) and refuse if VAULT_AUTH=token
#    is hard-coded somewhere downstream.
unset VAULT_TOKEN

cd -- "$(dirname -- "$0")"
exec terraform "$@"

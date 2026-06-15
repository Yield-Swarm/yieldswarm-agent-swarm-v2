#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"

VAULT_CLOUD_MOUNT="${VAULT_CLOUD_MOUNT:-cloud-secrets}"
VAULT_APP_MOUNT="${VAULT_APP_MOUNT:-app-secrets}"
VAULT_AUTH_PATH="${VAULT_AUTH_PATH:-approle}"

TERRAFORM_POLICY_NAME="${TERRAFORM_POLICY_NAME:-terraform-cloud-read}"
AKASH_POLICY_NAME="${AKASH_POLICY_NAME:-akash-runtime-read}"

TERRAFORM_ROLE_NAME="${TERRAFORM_ROLE_NAME:-terraform-ci}"
AKASH_ROLE_NAME="${AKASH_ROLE_NAME:-akash-runtime}"

require_bin() {
  local bin_name="$1"
  if ! command -v "${bin_name}" >/dev/null 2>&1; then
    echo "Missing required binary: ${bin_name}" >&2
    exit 1
  fi
}

is_kv_v2_mount() {
  local mount_name="$1"
  python3 - "$mount_name" <<'PY'
import json
import subprocess
import sys

mount = sys.argv[1] + "/"
raw = subprocess.check_output(["vault", "secrets", "list", "-format=json"], text=True)
mounts = json.loads(raw)
details = mounts.get(mount)
if not details:
    raise SystemExit(1)
is_kv = details.get("type") == "kv"
is_v2 = details.get("options", {}).get("version") == "2"
raise SystemExit(0 if (is_kv and is_v2) else 2)
PY
}

ensure_kv_v2_mount() {
  local mount_name="$1"

  if is_kv_v2_mount "${mount_name}"; then
    echo "KV v2 mount already configured at ${mount_name}/"
    return
  fi

  local status=$?
  if [[ "${status}" -eq 2 ]]; then
    echo "Mount ${mount_name}/ exists but is not kv-v2. Refusing to continue." >&2
    exit 1
  fi

  echo "Enabling KV v2 at ${mount_name}/"
  vault secrets enable -path="${mount_name}" -version=2 kv
}

ensure_auth_mount() {
  local auth_name="$1"
  if vault auth list | awk '{print $1}' | grep -qx "${auth_name}/"; then
    echo "Auth mount already enabled at ${auth_name}/"
    return
  fi

  echo "Enabling auth mount at ${auth_name}/"
  vault auth enable -path="${auth_name}" approle
}

write_policy() {
  local policy_name="$1"
  local policy_file="$2"

  if [[ ! -f "${policy_file}" ]]; then
    echo "Policy file not found: ${policy_file}" >&2
    exit 1
  fi

  echo "Writing policy ${policy_name} from ${policy_file}"
  vault policy write "${policy_name}" "${policy_file}"
}

render_policy_template() {
  local template_file="$1"
  local output_file="$2"

  sed \
    -e "s|cloud-secrets|${VAULT_CLOUD_MOUNT}|g" \
    -e "s|app-secrets|${VAULT_APP_MOUNT}|g" \
    "${template_file}" > "${output_file}"
}

configure_approle() {
  local role_name="$1"
  local policy_name="$2"
  local token_ttl="$3"
  local token_max_ttl="$4"
  local token_num_uses="$5"
  local secret_id_ttl="$6"

  echo "Configuring AppRole ${role_name} with policy ${policy_name}"
  vault write "auth/${VAULT_AUTH_PATH}/role/${role_name}" \
    token_policies="${policy_name}" \
    token_ttl="${token_ttl}" \
    token_max_ttl="${token_max_ttl}" \
    token_num_uses="${token_num_uses}" \
    secret_id_ttl="${secret_id_ttl}"
}

print_role_credentials() {
  local role_name="$1"

  local role_id
  role_id="$(vault read -field=role_id "auth/${VAULT_AUTH_PATH}/role/${role_name}/role-id")"

  local wrapped_secret_id_token
  wrapped_secret_id_token="$(
    vault write -wrap-ttl=5m -field=wrapping_token \
      "auth/${VAULT_AUTH_PATH}/role/${role_name}/secret-id"
  )"

  echo ""
  echo "Role: ${role_name}"
  echo "  Role ID: ${role_id}"
  echo "  Wrapped Secret ID Token (5m TTL): ${wrapped_secret_id_token}"
  echo "  Unwrap with: vault unwrap ${wrapped_secret_id_token}"
}

main() {
  require_bin vault
  require_bin python3

  if ! vault status >/dev/null 2>&1; then
    echo "Vault is not reachable or you are not authenticated. Set VAULT_ADDR and login first." >&2
    exit 1
  fi

  ensure_kv_v2_mount "${VAULT_CLOUD_MOUNT}"
  ensure_kv_v2_mount "${VAULT_APP_MOUNT}"
  ensure_auth_mount "${VAULT_AUTH_PATH}"

  local terraform_policy_rendered
  terraform_policy_rendered="$(mktemp)"
  local akash_policy_rendered
  akash_policy_rendered="$(mktemp)"
  trap 'rm -f "${terraform_policy_rendered}" "${akash_policy_rendered}"' EXIT

  render_policy_template "${POLICY_DIR}/terraform-cloud-read.hcl" "${terraform_policy_rendered}"
  render_policy_template "${POLICY_DIR}/akash-runtime-read.hcl" "${akash_policy_rendered}"

  write_policy "${TERRAFORM_POLICY_NAME}" "${terraform_policy_rendered}"
  write_policy "${AKASH_POLICY_NAME}" "${akash_policy_rendered}"

  configure_approle "${TERRAFORM_ROLE_NAME}" "${TERRAFORM_POLICY_NAME}" "15m" "1h" "20" "30m"
  configure_approle "${AKASH_ROLE_NAME}" "${AKASH_POLICY_NAME}" "15m" "1h" "0" "24h"

  print_role_credentials "${TERRAFORM_ROLE_NAME}"
  print_role_credentials "${AKASH_ROLE_NAME}"
}

main "$@"

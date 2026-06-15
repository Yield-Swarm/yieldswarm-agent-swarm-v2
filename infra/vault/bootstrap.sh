#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"

require_bin() {
  local binary="$1"
  if ! command -v "${binary}" >/dev/null 2>&1; then
    echo "Missing required binary: ${binary}" >&2
    exit 1
  fi
}

ensure_kv_v2_mount() {
  local mount="$1"
  local description="$2"
  local mount_key="${mount}/"

  if vault secrets list -format=json | jq -e --arg key "${mount_key}" 'has($key)' >/dev/null; then
    local version
    version="$(vault secrets list -format=json | jq -r --arg key "${mount_key}" '.[$key].options.version // "1"')"
    if [[ "${version}" != "2" ]]; then
      echo "Mount ${mount} exists but is not kv-v2 (found version=${version})." >&2
      exit 1
    fi
    echo "kv-v2 mount ${mount} already enabled."
    return
  fi

  vault secrets enable -path="${mount}" -description="${description}" kv-v2
  echo "Enabled kv-v2 mount ${mount}."
}

ensure_approle_auth() {
  if vault auth list -format=json | jq -e 'has("approle/")' >/dev/null; then
    echo "AppRole auth already enabled."
    return
  fi

  vault auth enable approle
  echo "Enabled AppRole auth."
}

write_policy() {
  local name="$1"
  local file="$2"

  if [[ ! -f "${file}" ]]; then
    echo "Policy file not found: ${file}" >&2
    exit 1
  fi

  vault policy write "${name}" "${file}"
  echo "Applied policy ${name}."
}

ensure_approle_role() {
  local role_name="$1"
  local policy_name="$2"
  local token_ttl="$3"
  local token_max_ttl="$4"
  local secret_id_ttl="$5"
  local secret_id_num_uses="$6"

  vault write "auth/approle/role/${role_name}" \
    token_policies="${policy_name}" \
    token_ttl="${token_ttl}" \
    token_max_ttl="${token_max_ttl}" \
    token_no_default_policy=true \
    bind_secret_id=true \
    secret_id_ttl="${secret_id_ttl}" \
    secret_id_num_uses="${secret_id_num_uses}" >/dev/null

  local role_id
  role_id="$(vault read -field=role_id "auth/approle/role/${role_name}/role-id")"
  echo "Configured AppRole ${role_name} (role_id=${role_id})."
}

print_next_steps() {
  cat <<'EOF'

Bootstrap complete.

Generate Terraform AppRole credentials:
  vault read -field=role_id auth/approle/role/terraform-read/role-id
  vault write -f -field=secret_id auth/approle/role/terraform-read/secret-id

Generate Akash runtime AppRole credentials:
  vault read -field=role_id auth/approle/role/akash-runtime/role-id
  vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id
EOF
}

main() {
  require_bin vault
  require_bin jq

  : "${VAULT_ADDR:?Set VAULT_ADDR before running this script.}"
  : "${VAULT_TOKEN:?Set VAULT_TOKEN before running this script.}"

  ensure_kv_v2_mount "cloud" "Cloud provider credentials"
  ensure_kv_v2_mount "rpc" "RPC credentials and endpoints"
  ensure_kv_v2_mount "app" "Application runtime secrets"

  ensure_approle_auth

  write_policy "terraform-read" "${POLICY_DIR}/terraform-read.hcl"
  write_policy "akash-runtime" "${POLICY_DIR}/akash-runtime.hcl"

  ensure_approle_role "terraform-read" "terraform-read" "1h" "4h" "24h" "5"
  ensure_approle_role "akash-runtime" "akash-runtime" "30m" "2h" "15m" "1"

  print_next_steps
}

main "$@"

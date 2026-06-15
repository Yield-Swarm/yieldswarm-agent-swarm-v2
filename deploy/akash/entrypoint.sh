#!/usr/bin/env bash

set -euo pipefail
umask 077

required_env_vars=(
  VAULT_ADDR
  VAULT_ROLE_ID
  VAULT_SECRET_ID
  VAULT_SECRET_PATHS
)

for name in "${required_env_vars[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
done

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI is required in the container image" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required in the container image" >&2
  exit 1
fi

VAULT_AUTH_PATH="${VAULT_AUTH_PATH:-auth/approle/login}"
VAULT_ENV_FILE="${VAULT_ENV_FILE:-/run/secrets/agentswarm.env}"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmpdir}"
}
trap cleanup EXIT

export VAULT_ADDR
if [[ -n "${VAULT_NAMESPACE:-}" ]]; then
  export VAULT_NAMESPACE
fi

login_payload="$(vault write -format=json "${VAULT_AUTH_PATH}" role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}")"
export VAULT_TOKEN
VAULT_TOKEN="$(printf '%s' "${login_payload}" | jq -er '.auth.client_token')"

mapfile -t secret_paths < <(
  python3 - <<'PY'
import os

for chunk in os.environ["VAULT_SECRET_PATHS"].replace(",", "\n").splitlines():
    value = chunk.strip()
    if value:
        print(value)
PY
)

if [[ "${#secret_paths[@]}" -eq 0 ]]; then
  echo "VAULT_SECRET_PATHS did not contain any usable paths" >&2
  exit 1
fi

secret_files=()
for index in "${!secret_paths[@]}"; do
  secret_path="${secret_paths[${index}]}"
  secret_file="${tmpdir}/${index}.json"
  vault kv get -format=json "${secret_path}" > "${secret_file}"
  secret_files+=("${secret_file}")
done

python3 /app/deploy/akash/render_vault_env.py --output "${VAULT_ENV_FILE}" "${secret_files[@]}"

vault token revoke -self >/dev/null 2>&1 || true
unset VAULT_TOKEN
unset VAULT_ROLE_ID
unset VAULT_SECRET_ID

set -a
# shellcheck source=/dev/null
. "${VAULT_ENV_FILE}"
set +a

exec "$@"

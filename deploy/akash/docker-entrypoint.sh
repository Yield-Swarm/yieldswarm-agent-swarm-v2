#!/usr/bin/env sh
set -eu

umask 077

require_env() {
  var_name="$1"
  eval "var_value=\${${var_name}:-}"
  if [ -z "${var_value}" ]; then
    echo "Required environment variable is not set: ${var_name}" >&2
    exit 1
  fi
}

require_env "VAULT_ADDR"
require_env "VAULT_ROLE_ID"
require_env "VAULT_SECRET_ID"

VAULT_AUTH_PATH="${VAULT_AUTH_PATH:-approle}"
VAULT_SECRET_MOUNT="${VAULT_SECRET_MOUNT:-app-secrets}"
VAULT_SECRET_PATH="${VAULT_SECRET_PATH:-akash/runtime}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-}"

secrets_tmp="$(mktemp)"

cleanup() {
  rm -f "${secrets_tmp}"
  unset VAULT_TOKEN
  unset VAULT_SECRET_ID
}
trap cleanup EXIT INT TERM

vault_namespace_header() {
  if [ -n "${VAULT_NAMESPACE}" ]; then
    printf '%s' "-H X-Vault-Namespace:${VAULT_NAMESPACE}"
  fi
}

AUTH_PAYLOAD="$(printf '{"role_id":"%s","secret_id":"%s"}' "${VAULT_ROLE_ID}" "${VAULT_SECRET_ID}")"

LOGIN_RESPONSE="$(
  curl -sS --fail --retry 5 --retry-all-errors --connect-timeout 5 --max-time 20 \
    -H "Content-Type: application/json" \
    $(vault_namespace_header) \
    --request POST \
    --data "${AUTH_PAYLOAD}" \
    "${VAULT_ADDR}/v1/auth/${VAULT_AUTH_PATH}/login"
)"

VAULT_TOKEN="$(
  printf '%s' "${LOGIN_RESPONSE}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["auth"]["client_token"])'
)"

if [ -z "${VAULT_TOKEN}" ]; then
  echo "Vault authentication failed: empty client token" >&2
  exit 1
fi

SECRET_RESPONSE="$(
  curl -sS --fail --retry 5 --retry-all-errors --connect-timeout 5 --max-time 20 \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    $(vault_namespace_header) \
    --request GET \
    "${VAULT_ADDR}/v1/${VAULT_SECRET_MOUNT}/data/${VAULT_SECRET_PATH}"
)"

export SECRET_RESPONSE
python3 - "${secrets_tmp}" <<'PY'
import json
import os
import re
import shlex
import sys

output_path = sys.argv[1]
payload = json.loads(os.environ["SECRET_RESPONSE"])
secret_data = payload.get("data", {}).get("data", {})

if not isinstance(secret_data, dict) or not secret_data:
    raise SystemExit("Vault secret payload is empty or malformed")

valid_key = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

with open(output_path, "w", encoding="utf-8") as handle:
    for key, value in secret_data.items():
        if not valid_key.match(key):
            raise SystemExit(f"Invalid environment key from Vault: {key}")
        handle.write(f"{key}={shlex.quote(str(value))}\n")
PY
unset SECRET_RESPONSE

set -a
# shellcheck disable=SC1090
. "${secrets_tmp}"
set +a

exec "$@"

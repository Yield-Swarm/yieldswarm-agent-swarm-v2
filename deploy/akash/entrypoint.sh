#!/usr/bin/env sh
set -eu

log() {
  printf '%s\n' "$*" >&2
}

require_env() {
  var_name="$1"
  eval "var_value=\${$var_name:-}"
  if [ -z "${var_value}" ]; then
    log "Missing required environment variable: ${var_name}"
    exit 1
  fi
}

require_env "VAULT_ADDR"

VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-kv}"
VAULT_SECRET_PATH="${VAULT_SECRET_PATH:-runtime/akash/prod}"
REQUIRED_SECRET_KEYS="${REQUIRED_SECRET_KEYS:-}"
VAULT_REVOKE_TOKEN_ON_EXIT="${VAULT_REVOKE_TOKEN_ON_EXIT:-1}"

if [ -z "${VAULT_TOKEN:-}" ]; then
  require_env "VAULT_ROLE_ID"
  require_env "VAULT_SECRET_ID"
  VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}")"
  export VAULT_TOKEN
fi

SECRET_ENV_FILE="$(mktemp)"
chmod 600 "${SECRET_ENV_FILE}"

cleanup() {
  rm -f "${SECRET_ENV_FILE}"
  if [ "${VAULT_REVOKE_TOKEN_ON_EXIT}" = "1" ]; then
    vault token revoke -self >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

vault kv get -mount="${VAULT_KV_MOUNT}" -format=json "${VAULT_SECRET_PATH}" \
  | python3 - "${SECRET_ENV_FILE}" "${REQUIRED_SECRET_KEYS}" <<'PY'
import json
import re
import shlex
import sys

output_file = sys.argv[1]
required_keys_csv = sys.argv[2].strip()

doc = json.load(sys.stdin)
payload = doc.get("data", {}).get("data", {})

if not payload:
    raise SystemExit("Vault secret path returned no key-value data")

required_keys = [k.strip() for k in required_keys_csv.split(",") if k.strip()]
missing = [k for k in required_keys if k not in payload]
if missing:
    raise SystemExit(f"Missing required secret keys: {', '.join(missing)}")

key_pattern = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
with open(output_file, "w", encoding="utf-8") as fh:
    for key, value in payload.items():
        if not key_pattern.match(key):
            raise SystemExit(f"Invalid env var key in Vault payload: {key}")
        fh.write(f"export {key}={shlex.quote(str(value))}\n")
PY

# shellcheck source=/dev/null
. "${SECRET_ENV_FILE}"

if [ "$#" -eq 0 ]; then
  set -- python /app/agents/akash-optimizer.py
fi

exec "$@"

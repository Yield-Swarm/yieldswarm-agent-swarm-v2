#!/usr/bin/env sh
set -eu

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 127
  fi
}

trim() {
  printf '%s' "$1" | python3 -c 'import sys; print(sys.stdin.read().strip())'
}

vault_request() {
  method="$1"
  token="$2"
  api_path="$3"
  body_file="${4:-}"

  set -- -fsS --request "$method" \
    --connect-timeout "${VAULT_CONNECT_TIMEOUT:-5}" \
    --max-time "${VAULT_MAX_TIME:-20}" \
    --header "Accept: application/json"

  if [ -n "$token" ]; then
    set -- "$@" --header "X-Vault-Token: $token"
  fi

  if [ -n "${VAULT_NAMESPACE:-}" ]; then
    set -- "$@" --header "X-Vault-Namespace: $VAULT_NAMESPACE"
  fi

  if [ -n "${VAULT_CACERT:-}" ]; then
    set -- "$@" --cacert "$VAULT_CACERT"
  fi

  if [ -n "${VAULT_CLIENT_CERT:-}" ]; then
    set -- "$@" --cert "$VAULT_CLIENT_CERT"
  fi

  if [ -n "${VAULT_CLIENT_KEY:-}" ]; then
    set -- "$@" --key "$VAULT_CLIENT_KEY"
  fi

  if [ "${VAULT_SKIP_VERIFY:-false}" = "true" ]; then
    set -- "$@" --insecure
  fi

  if [ -n "$body_file" ]; then
    set -- "$@" --header "Content-Type: application/json" --data-binary "@$body_file"
  fi

  curl "$@" "${VAULT_ADDR%/}/v1/$api_path"
}

json_value() {
  file="$1"
  path="$2"

  python3 - "$file" "$path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    value = json.load(handle)

for part in sys.argv[2].split("."):
    value = value[part]

if isinstance(value, (dict, list)):
    print(json.dumps(value, separators=(",", ":")))
else:
    print(value)
PY
}

write_login_payload() {
  role_id="$1"
  secret_id="$2"
  output_file="$3"

  ROLE_ID="$role_id" SECRET_ID="$secret_id" python3 - <<'PY' > "$output_file"
import json
import os

print(json.dumps({
    "role_id": os.environ["ROLE_ID"],
    "secret_id": os.environ["SECRET_ID"],
}))
PY
}

append_secret_exports() {
  response_file="$1"
  env_file="$2"

  python3 - "$response_file" "$env_file" <<'PY'
import json
import re
import shlex
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

data = payload.get("data", {}).get("data", {})
if not isinstance(data, dict):
    raise SystemExit("Vault KV response did not contain a data object")

identifier = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

with open(sys.argv[2], "a", encoding="utf-8") as env_file:
    for key in sorted(data):
        if not identifier.match(key):
            print(f"Skipping Vault key with invalid environment name: {key}", file=sys.stderr)
            continue

        value = data[key]
        if value is None:
            continue
        if isinstance(value, (dict, list)):
            rendered = json.dumps(value, separators=(",", ":"))
        else:
            rendered = str(value)

        env_file.write(f"export {key}={shlex.quote(rendered)}\n")
PY
}

require_command curl
require_command python3

: "${VAULT_ADDR:?VAULT_ADDR is required}"

VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-secret}"
AKASH_VAULT_SECRET_PATHS="${AKASH_VAULT_SECRET_PATHS:-app/agentswarm,cloud/runpod,rpc/mainnet}"

WORK_DIR="$(mktemp -d)"
ENV_FILE="$WORK_DIR/vault.env"
TOKEN_FILE="$WORK_DIR/vault-token.json"
LOGIN_FILE="$WORK_DIR/login.json"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

if [ -n "${VAULT_TOKEN_FILE:-}" ]; then
  VAULT_SESSION_TOKEN="$(trim "$(cat "$VAULT_TOKEN_FILE")")"
elif [ -n "${VAULT_TOKEN:-}" ]; then
  VAULT_SESSION_TOKEN="$VAULT_TOKEN"
else
  : "${VAULT_ROLE_ID:?VAULT_ROLE_ID is required when VAULT_TOKEN or VAULT_TOKEN_FILE is not supplied}"

  if [ -n "${VAULT_WRAPPED_SECRET_ID_FILE:-}" ]; then
    WRAPPED_SECRET_ID="$(trim "$(cat "$VAULT_WRAPPED_SECRET_ID_FILE")")"
  else
    : "${VAULT_WRAPPED_SECRET_ID:?VAULT_WRAPPED_SECRET_ID or VAULT_WRAPPED_SECRET_ID_FILE is required when VAULT_TOKEN is not supplied}"
    WRAPPED_SECRET_ID="$VAULT_WRAPPED_SECRET_ID"
  fi

  vault_request POST "$WRAPPED_SECRET_ID" "sys/wrapping/unwrap" > "$TOKEN_FILE"
  VAULT_SECRET_ID="$(json_value "$TOKEN_FILE" "data.secret_id")"

  write_login_payload "$VAULT_ROLE_ID" "$VAULT_SECRET_ID" "$LOGIN_FILE"
  vault_request POST "" "auth/${VAULT_AUTH_MOUNT:-approle}/login" "$LOGIN_FILE" > "$TOKEN_FILE"
  VAULT_SESSION_TOKEN="$(json_value "$TOKEN_FILE" "auth.client_token")"
fi

unset VAULT_TOKEN VAULT_SECRET_ID VAULT_WRAPPED_SECRET_ID WRAPPED_SECRET_ID

SECRET_COUNT=0
OLD_IFS="$IFS"
IFS=","
for raw_path in $AKASH_VAULT_SECRET_PATHS; do
  SECRET_PATH="$(trim "$raw_path")"
  if [ -z "$SECRET_PATH" ]; then
    continue
  fi

  RESPONSE_FILE="$WORK_DIR/secret-$SECRET_COUNT.json"
  vault_request GET "$VAULT_SESSION_TOKEN" "${VAULT_KV_MOUNT}/data/${SECRET_PATH}" > "$RESPONSE_FILE"
  append_secret_exports "$RESPONSE_FILE" "$ENV_FILE"
  SECRET_COUNT=$((SECRET_COUNT + 1))
done
IFS="$OLD_IFS"

set -a
. "$ENV_FILE"
set +a

echo "Loaded Vault secrets from $SECRET_COUNT path(s)." >&2

if [ "$#" -eq 0 ]; then
  set -- python /app/agents/akash-optimizer.py
fi

exec "$@"

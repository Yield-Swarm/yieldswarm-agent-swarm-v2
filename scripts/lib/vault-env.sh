#!/usr/bin/env bash
set -euo pipefail

vault__python() {
  if [ -n "${PYTHON_BIN:-}" ]; then
    "$PYTHON_BIN" "$@"
  elif command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  elif command -v python >/dev/null 2>&1; then
    python "$@"
  else
    echo "python3 or python is required for Vault secret loading" >&2
    return 1
  fi
}

vault__trim_slashes() {
  local value="${1:-}"
  value="${value#/}"
  value="${value%/}"
  printf '%s' "$value"
}

vault__read_secret_value() {
  local env_name="$1"
  local file_env_name="${2:-${env_name}_FILE}"
  local value="${!env_name:-}"
  local file_path="${!file_env_name:-}"

  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi

  if [ -n "$file_path" ] && [ -r "$file_path" ]; then
    vault__python - "$file_path" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").strip(), end="")
PY
    return 0
  fi

  return 1
}

vault__curl() {
  local method="$1"
  local path="$2"
  shift 2

  if [ -z "${VAULT_ADDR:-}" ]; then
    echo "VAULT_ADDR is required for Vault secret loading" >&2
    return 1
  fi

  local url="${VAULT_ADDR%/}/v1/$(vault__trim_slashes "$path")"
  local namespace_args=()
  if [ -n "${VAULT_NAMESPACE:-}" ]; then
    namespace_args=(-H "X-Vault-Namespace: ${VAULT_NAMESPACE}")
  fi

  curl --fail --silent --show-error \
    --request "$method" \
    "${namespace_args[@]}" \
    "$@" \
    "$url"
}

vault__login_approle() {
  local role_id secret_id auth_path
  role_id="$(vault__read_secret_value VAULT_ROLE_ID VAULT_ROLE_ID_FILE)"
  secret_id="$(vault__read_secret_value VAULT_SECRET_ID VAULT_SECRET_ID_FILE)"
  auth_path="${VAULT_APPROLE_AUTH_PATH:-auth/approle/login}"

  vault__python - "$role_id" "$secret_id" <<'PY' | vault__curl POST "$auth_path" --data @- | vault__python -c 'import json,sys; print(json.load(sys.stdin)["auth"]["client_token"], end="")'
import json
import sys

print(json.dumps({"role_id": sys.argv[1], "secret_id": sys.argv[2]}), end="")
PY
}

vault__login_jwt() {
  local jwt role auth_path
  jwt="$(vault__read_secret_value VAULT_JWT VAULT_JWT_FILE)"
  role="${VAULT_JWT_ROLE:-${ODYSSEUS_VAULT_ROLE:-}}"
  auth_path="${VAULT_JWT_AUTH_PATH:-auth/jwt/login}"

  if [ -z "$role" ]; then
    echo "VAULT_JWT_ROLE or ODYSSEUS_VAULT_ROLE is required for JWT Vault auth" >&2
    return 1
  fi

  vault__python - "$role" "$jwt" <<'PY' | vault__curl POST "$auth_path" --data @- | vault__python -c 'import json,sys; print(json.load(sys.stdin)["auth"]["client_token"], end="")'
import json
import sys

print(json.dumps({"role": sys.argv[1], "jwt": sys.argv[2]}), end="")
PY
}

vault_token() {
  if vault__read_secret_value VAULT_TOKEN VAULT_TOKEN_FILE; then
    return 0
  fi

  case "${VAULT_AUTH_METHOD:-jwt}" in
    approle)
      vault__login_approle
      ;;
    jwt)
      vault__login_jwt
      ;;
    token)
      echo "VAULT_TOKEN or VAULT_TOKEN_FILE is required when VAULT_AUTH_METHOD=token" >&2
      return 1
      ;;
    *)
      echo "Unsupported VAULT_AUTH_METHOD=${VAULT_AUTH_METHOD}" >&2
      return 1
      ;;
  esac
}

vault_export_env() {
  local secret_path="$1"
  local token tmp_file

  token="$(vault_token)"
  tmp_file="$(mktemp)"
  chmod 600 "$tmp_file"

  vault__curl GET "$secret_path" -H "X-Vault-Token: ${token}" | vault__python -c '
import json
import os
import re
import shlex
import sys

target = sys.argv[1]
payload = json.load(sys.stdin)
data = payload.get("data", {})

# Support both KV v1 payloads and KV v2 payloads at /<mount>/data/<path>.
if isinstance(data.get("data"), dict):
    data = data["data"]

with open(target, "w", encoding="utf-8") as handle:
    for key, value in sorted(data.items()):
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            continue
        if isinstance(value, (dict, list)):
            value = json.dumps(value, separators=(",", ":"))
        elif value is None:
            value = ""
        else:
            value = str(value)
        handle.write(f"export {key}={shlex.quote(value)}\n")
' "$tmp_file"

  # shellcheck disable=SC1090
  . "$tmp_file"
  rm -f "$tmp_file"
}

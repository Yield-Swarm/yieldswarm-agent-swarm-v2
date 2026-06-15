#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

readonly SCRIPT_NAME="vault-entrypoint"
readonly DEFAULT_BOOTSTRAP_ENV_FILE="/run/secrets/.env"
readonly DEFAULT_RENDERED_ENV_FILE="/run/secrets/runtime.env"

BOOTSTRAP_ENV_FILE="${BOOTSTRAP_ENV_FILE:-$DEFAULT_BOOTSTRAP_ENV_FILE}"
RENDERED_ENV_FILE="${RENDERED_ENV_FILE:-$DEFAULT_RENDERED_ENV_FILE}"
VAULT_SECRET_WAIT_SECONDS="${VAULT_SECRET_WAIT_SECONDS:-300}"
VAULT_SECRET_WAIT_INTERVAL="${VAULT_SECRET_WAIT_INTERVAL:-5}"
VAULT_LOGIN_PATH="${VAULT_LOGIN_PATH:-auth/approle/login}"

VAULT_TOKEN=""
VAULT_CACERT_TEMP_FILE=""

log() {
  printf '[%s] %s\n' "$SCRIPT_NAME" "$*" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing required executable: $1"
    exit 127
  fi
}

cleanup() {
  unset VAULT_SECRET_ID
  unset VAULT_TOKEN

  if [[ -n "${VAULT_CACERT_TEMP_FILE}" && -f "${VAULT_CACERT_TEMP_FILE}" ]]; then
    rm -f "${VAULT_CACERT_TEMP_FILE}"
  fi
}

trap cleanup EXIT

wait_for_bootstrap_file() {
  local elapsed=0

  while [[ ! -s "$BOOTSTRAP_ENV_FILE" ]]; do
    if (( elapsed >= VAULT_SECRET_WAIT_SECONDS )); then
      log "bootstrap file was not injected within ${VAULT_SECRET_WAIT_SECONDS}s: ${BOOTSTRAP_ENV_FILE}"
      exit 1
    fi

    log "waiting for bootstrap file at ${BOOTSTRAP_ENV_FILE}"
    sleep "$VAULT_SECRET_WAIT_INTERVAL"
    elapsed=$((elapsed + VAULT_SECRET_WAIT_INTERVAL))
  done
}

load_bootstrap_env() {
  # shellcheck disable=SC1090
  set -a
  . "$BOOTSTRAP_ENV_FILE"
  set +a

  : "${VAULT_ADDR:?bootstrap file must define VAULT_ADDR}"
  : "${VAULT_ROLE_ID:?bootstrap file must define VAULT_ROLE_ID}"
  : "${VAULT_SECRET_ID:?bootstrap file must define VAULT_SECRET_ID}"
  : "${VAULT_KV_MOUNT:?bootstrap file must define VAULT_KV_MOUNT}"
  : "${VAULT_SECRET_PATHS:?bootstrap file must define VAULT_SECRET_PATHS}"

  if [[ -n "${VAULT_CACERT_B64:-}" ]]; then
    VAULT_CACERT_TEMP_FILE="$(mktemp)"
    printf '%s' "${VAULT_CACERT_B64}" | base64 -d > "${VAULT_CACERT_TEMP_FILE}"
    chmod 0600 "${VAULT_CACERT_TEMP_FILE}"
    export VAULT_CACERT="${VAULT_CACERT_TEMP_FILE}"
  fi
}

run_vault_curl() {
  local -a args
  args=(
    --silent
    --show-error
    --fail
    --retry 5
    --retry-all-errors
    --connect-timeout 5
  )

  if [[ -n "${VAULT_NAMESPACE:-}" ]]; then
    args+=(-H "X-Vault-Namespace: ${VAULT_NAMESPACE}")
  fi

  if [[ -n "${VAULT_CACERT:-}" ]]; then
    args+=(--cacert "${VAULT_CACERT}")
  fi

  curl "${args[@]}" "$@"
}

vault_login() {
  local login_response
  local payload
  payload="$(
    python - <<'PY'
import json
import os

print(
    json.dumps(
        {
            "role_id": os.environ["VAULT_ROLE_ID"],
            "secret_id": os.environ["VAULT_SECRET_ID"],
        }
    )
)
PY
  )"

  login_response="$(
    run_vault_curl \
      -H 'Content-Type: application/json' \
      --request POST \
      --data "${payload}" \
      "${VAULT_ADDR%/}/v1/${VAULT_LOGIN_PATH}"
  )"

  VAULT_TOKEN="$(
    VAULT_LOGIN_RESPONSE="${login_response}" python - <<'PY'
import json
import os

response = json.loads(os.environ["VAULT_LOGIN_RESPONSE"])
token = response.get("auth", {}).get("client_token")
if not token:
    raise SystemExit("Vault login succeeded but did not return a client token")
print(token)
PY
  )"

  export VAULT_TOKEN
}

fetch_secret_path() {
  local secret_name="$1"

  run_vault_curl \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR%/}/v1/${VAULT_KV_MOUNT}/data/${secret_name}"
}

render_runtime_env() {
  local response
  local tmp_file
  IFS=',' read -r -a secret_names <<<"${VAULT_SECRET_PATHS}"
  tmp_file="$(mktemp)"

  : > "${tmp_file}"

  for secret_name in "${secret_names[@]}"; do
    if [[ -z "${secret_name}" ]]; then
      continue
    fi

    response="$(fetch_secret_path "${secret_name}")"

    VAULT_SECRET_RESPONSE="${response}" python - "${tmp_file}" <<'PY'
import json
import os
import shlex
import sys
from pathlib import Path

destination = Path(sys.argv[1])
payload = json.loads(os.environ["VAULT_SECRET_RESPONSE"])
data = payload.get("data", {}).get("data", {})

if not isinstance(data, dict):
    raise SystemExit("Vault KV payload missing data.data object")

with destination.open("a", encoding="utf-8") as handle:
    for key, value in sorted(data.items()):
        if value is None:
            continue
        if isinstance(value, (dict, list)):
            rendered = json.dumps(value, separators=(",", ":"))
        else:
            rendered = str(value)
        handle.write(f"export {key}={shlex.quote(rendered)}\n")
PY
  done

  mv "${tmp_file}" "${RENDERED_ENV_FILE}"
  chmod 0600 "${RENDERED_ENV_FILE}"

  # shellcheck disable=SC1090
  set -a
  . "${RENDERED_ENV_FILE}"
  set +a
}

main() {
  require_command curl
  require_command python
  require_command base64

  wait_for_bootstrap_file
  load_bootstrap_env
  vault_login
  render_runtime_env

  unset VAULT_SECRET_ID
  unset VAULT_TOKEN

  if [[ "$#" -eq 0 ]]; then
    set -- python /app/agents/akash-optimizer.py
  fi

  exec "$@"
}

main "$@"

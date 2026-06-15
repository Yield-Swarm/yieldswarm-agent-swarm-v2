#!/usr/bin/env bash
# JWT utilities for Akash provider-services tokens (no external deps beyond python3).
set -euo pipefail

# Seconds before expiry to treat token as stale (default 5 minutes).
AKASH_JWT_REFRESH_BUFFER_SECONDS="${AKASH_JWT_REFRESH_BUFFER_SECONDS:-300}"

akash_jwt__read_token() {
  if [[ -n "${AKASH_JWT:-}" ]]; then
    printf '%s' "${AKASH_JWT}"
    return 0
  fi
  if [[ -n "${AKASH_JWT_FILE:-}" && -r "${AKASH_JWT_FILE}" ]]; then
    tr -d '\n' < "${AKASH_JWT_FILE}"
    return 0
  fi
  return 1
}

# Prints: valid|expired|missing|malformed
akash_jwt_status() {
  local token
  token="$(akash_jwt__read_token 2>/dev/null || true)"
  if [[ -z "${token}" ]]; then
    echo "missing"
    return 0
  fi
  python3 - "$token" "${AKASH_JWT_REFRESH_BUFFER_SECONDS}" <<'PY'
import base64, json, sys, time

token, buf = sys.argv[1], int(sys.argv[2])
parts = token.split(".")
if len(parts) != 3:
    print("malformed")
    raise SystemExit(0)
payload = parts[1] + "=" * (-len(parts[1]) % 4)
try:
    data = json.loads(base64.urlsafe_b64decode(payload))
except Exception:
    print("malformed")
    raise SystemExit(0)
exp = int(data.get("exp") or 0)
now = int(time.time())
if exp <= 0:
    print("malformed")
elif now >= exp:
    print("expired")
elif now >= exp - buf:
    print("stale")
else:
    print("valid")
PY
}

# Prints Unix expiry timestamp or empty.
akash_jwt_exp() {
  local token
  token="$(akash_jwt__read_token 2>/dev/null || true)"
  [[ -n "${token}" ]] || return 1
  python3 - "$token" <<'PY'
import base64, json, sys
token = sys.argv[1]
parts = token.split(".")
if len(parts) != 3:
    raise SystemExit(1)
payload = parts[1] + "=" * (-len(parts[1]) % 4)
data = json.loads(base64.urlsafe_b64decode(payload))
print(int(data.get("exp") or 0))
PY
}

akash_jwt_write_meta() {
  local token="$1"
  local meta_file="${2:-}"
  [[ -n "${meta_file}" ]] || return 0
  python3 - "$token" "$meta_file" <<'PY'
import base64, json, sys, time, pathlib
token, path = sys.argv[1], sys.argv[2]
parts = token.split(".")
payload = parts[1] + "=" * (-len(parts[1]) % 4)
data = json.loads(base64.urlsafe_b64decode(payload))
meta = {
    "exp": int(data.get("exp") or 0),
    "iat": int(data.get("iat") or 0),
    "iss": data.get("iss", ""),
    "generated_at": int(time.time()),
}
pathlib.Path(path).write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
PY
}

akash_jwt_secure_write() {
  local token="$1"
  local jwt_file="$2"
  local env_file="$3"
  local meta_file="$4"
  umask 077
  mkdir -p "$(dirname "${jwt_file}")"
  printf '%s' "${token}" > "${jwt_file}"
  chmod 600 "${jwt_file}"
  cat > "${env_file}" <<EOF
# Akash JWT — session-only, gitignored (.run/). Do not commit.
export AKASH_JWT_FILE="${jwt_file}"
export AKASH_AUTH_METHOD=jwt
# Load token from file (avoids leaking into shell history):
export AKASH_JWT="\$(cat "${jwt_file}")"
EOF
  chmod 600 "${env_file}"
  akash_jwt_write_meta "${token}" "${meta_file}"
}

# Export pattern for subprocesses: sets AKASH_JWT from file if not already set.
akash_jwt_export() {
  if [[ -z "${AKASH_JWT:-}" && -n "${AKASH_JWT_FILE:-}" && -r "${AKASH_JWT_FILE}" ]]; then
    # shellcheck disable=SC2155
    export AKASH_JWT="$(tr -d '\n' < "${AKASH_JWT_FILE}")"
  fi
}

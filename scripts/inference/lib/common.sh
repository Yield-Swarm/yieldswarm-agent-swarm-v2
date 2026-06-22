#!/usr/bin/env bash
# Shared helpers for open-metal inference scripts.
set -euo pipefail

INFERENCE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${INFERENCE_LIB_DIR}/../../.." && pwd)"
MATRIX_FILE="${OPEN_METAL_MATRIX:-${REPO_ROOT}/config/inference/open-metal-matrix.json}"
LOG_DIR="${OPEN_METAL_LOG_DIR:-${HOME}/yieldswarm-logs}"
WORKSPACE_DIR="${YIELDSWARM_WORKSPACE:-${HOME}/yieldswarm-agent-swarm-v2}"

log()  { printf '[open-metal] %s\n' "$*"; }
warn() { printf '[open-metal][warn] %s\n' "$*" >&2; }
die()  { printf '[open-metal][fail] %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

ollama_api_base() {
  local host="${OLLAMA_HOST:-127.0.0.1:11434}"
  echo "http://${host/0.0.0.0/127.0.0.1}"
}

load_matrix_models() {
  python3 - <<'PY' "${MATRIX_FILE}"
import json, sys
path = sys.argv[1]
data = json.load(open(path))
models = list(data.get("ollama_local", {}).get("pull_models", []))
for m in models:
    print(m)
PY
}

matrix_litellm_port() {
  python3 - <<'PY' "${MATRIX_FILE}"
import json, sys
data = json.load(open(sys.argv[1]))
print(data.get("litellm", {}).get("port", 4000))
PY
}

ensure_log_dir() {
  run mkdir -p "${LOG_DIR}"
}

screen_start() {
  local name="$1"
  shift
  if command -v screen >/dev/null 2>&1; then
    run screen -dmS "${name}" "$@"
  else
    warn "screen not installed — run manually: $*"
  fi
}

wait_for_http() {
  local url="$1" timeout="${2:-120}"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "[dry-run] wait for ${url}"
    return 0
  fi
  for _ in $(seq 1 "${timeout}"); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  die "timeout waiting for ${url}"
}

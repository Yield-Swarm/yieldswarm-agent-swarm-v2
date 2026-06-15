#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=lib/vault-env.sh
. "${ROOT_DIR}/scripts/lib/vault-env.sh"

TARGET="${1:-${DEPLOY_TARGET:-akash}}"
ODYSSEUS_DEPLOY_VAULT_PATH="${ODYSSEUS_DEPLOY_VAULT_PATH:-kv/data/yieldswarm/odysseus/deploy}"
ODYSSEUS_RUNTIME_VAULT_PATH="${ODYSSEUS_RUNTIME_VAULT_PATH:-kv/data/yieldswarm/odysseus/runtime}"

export AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export ODYSSEUS_AGENT_COUNT="${ODYSSEUS_AGENT_COUNT:-84}"
export ODYSSEUS_RUNTIME_VAULT_PATH
export VAULT_AUTH_METHOD="${VAULT_AUTH_METHOD:-jwt}"
export VAULT_JWT_AUTH_PATH="${VAULT_JWT_AUTH_PATH:-auth/jwt/login}"
export VAULT_JWT_FILE="${VAULT_JWT_FILE:-/var/run/secrets/akash/serviceaccount/token}"
export VAULT_JWT_ROLE="${VAULT_JWT_ROLE:-yieldswarm-odysseus-runtime}"
export VAULT_KV_PATH="${VAULT_KV_PATH:-${ODYSSEUS_RUNTIME_VAULT_PATH}}"
export VAULT_NAMESPACE="${VAULT_NAMESPACE:-}"

load_deploy_config() {
  echo "Loading Odysseus deployment configuration from HashiCorp Vault path ${ODYSSEUS_DEPLOY_VAULT_PATH}" >&2
  vault_export_env "${ODYSSEUS_DEPLOY_VAULT_PATH}"

  export ODYSSEUS_IMAGE="${ODYSSEUS_IMAGE:-${image_repository:-ghcr.io/yieldswarm/odysseus:main}}"
  export YIELDSWARM_BRAIN_IMAGE="${YIELDSWARM_BRAIN_IMAGE:-ghcr.io/yieldswarm/odysseus-brain:latest}"
  export AKASH_NET="${AKASH_NET:-https://raw.githubusercontent.com/akash-network/net/main/mainnet}"
  export AKASH_CHAIN_ID="${AKASH_CHAIN_ID:-akashnet-2}"
  export AKASH_NODE="${AKASH_NODE:-https://rpc.akashnet.net:443}"
  export AKASH_FEES="${AKASH_FEES:-5000uakt}"
}

render_template() {
  local template="$1"
  local output="$2"

  vault__python - "$template" "$output" <<'PY'
import os
import pathlib
import re
import sys

template = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
pattern = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
text = template.read_text(encoding="utf-8")
missing = sorted({match.group(1) for match in pattern.finditer(text) if match.group(1) not in os.environ})

if missing:
    raise SystemExit(f"Missing template environment variables: {', '.join(missing)}")

output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(pattern.sub(lambda match: os.environ[match.group(1)], text), encoding="utf-8")
PY
}

build_image() {
  docker build -t "${ODYSSEUS_IMAGE}" "${ROOT_DIR}"
}

push_image() {
  docker push "${ODYSSEUS_IMAGE}"
}

render_akash_sdl() {
  local template="${ODYSSEUS_SDL_TEMPLATE:-${ROOT_DIR}/deploy/akash-odysseus.sdl.yml}"
  local output="${ROOT_DIR}/build/akash/odysseus.sdl.rendered.yml"
  render_template "${template}" "${output}"
  printf '%s\n' "${output}"
}

build_brain_image() {
  docker build -f "${ROOT_DIR}/docker/Dockerfile.odysseus-brain" \
    -t "${YIELDSWARM_BRAIN_IMAGE:-ghcr.io/yieldswarm/odysseus-brain:latest}" \
    "${ROOT_DIR}"
}

push_brain_image() {
  docker push "${YIELDSWARM_BRAIN_IMAGE:-ghcr.io/yieldswarm/odysseus-brain:latest}"
}

deploy_akash() {
  local rendered_sdl
  rendered_sdl="$(render_akash_sdl)"

  if [ "${AKASH_DRY_RUN:-false}" = "true" ]; then
    echo "AKASH_DRY_RUN=true; rendered SDL at ${rendered_sdl}" >&2
    return 0
  fi

  if ! command -v akash >/dev/null 2>&1; then
    echo "akash CLI is required for production Akash deployment" >&2
    return 1
  fi

  if [ -z "${AKASH_KEY_NAME:-}" ]; then
    echo "AKASH_KEY_NAME must be supplied by Vault deploy config or environment" >&2
    return 1
  fi

  akash tx deployment create "${rendered_sdl}" \
    --from "${AKASH_KEY_NAME}" \
    --chain-id "${AKASH_CHAIN_ID}" \
    --node "${AKASH_NODE}" \
    --fees "${AKASH_FEES}" \
    --yes
}

load_deploy_config

case "${TARGET}" in
  build)
    build_image
    ;;
  push)
    push_image
    ;;
  docker)
    build_image
    if [ "${PUSH_IMAGE:-true}" = "true" ]; then
      push_image
    fi
    ;;
  compose)
    docker compose --project-directory "${ROOT_DIR}" up -d --build odysseus
    ;;
  render-akash)
    render_akash_sdl
    ;;
  akash)
    if [ "${BUILD_IMAGE:-true}" = "true" ]; then
      build_brain_image
    fi
    if [ "${PUSH_IMAGE:-true}" = "true" ]; then
      push_brain_image
    fi
    deploy_akash
    ;;
  *)
    echo "Usage: $0 [build|push|docker|compose|render-akash|akash]" >&2
    exit 2
    ;;
esac

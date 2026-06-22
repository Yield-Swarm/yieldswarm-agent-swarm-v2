#!/usr/bin/env bash
# Start LiteLLM load balancer for open-metal model matrix.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

export DRY_RUN

LITELLM_CONFIG="${LITELLM_CONFIG:-${REPO_ROOT}/config/inference/litellm-open-metal.yaml}"
LITELLM_PORT="$(matrix_litellm_port)"
LITELLM_HOST="${LLM_ROUTER_BIND:-127.0.0.1}"

export LOCAL_OLLAMA_BASE_URL="${LOCAL_OLLAMA_BASE_URL:-$(ollama_api_base)}"
export YIELDSWARM_ROUTER_API_KEY="${YIELDSWARM_ROUTER_API_KEY:-open-metal-local}"
export RUNPOD_B200_VLLM_URL="${RUNPOD_B200_VLLM_URL:-http://127.0.0.1:8000/v1}"
export RUNPOD_H200_VLLM_URL="${RUNPOD_H200_VLLM_URL:-http://127.0.0.1:8001/v1}"
export RUNPOD_H100_VLLM_URL="${RUNPOD_H100_VLLM_URL:-http://127.0.0.1:8002/v1}"

start_docker_litellm() {
  local image="${YIELDSWARM_LITELLM_IMAGE:-ghcr.io/berriai/litellm:main-latest}"
  step "Starting LiteLLM via Docker on ${LITELLM_HOST}:${LITELLM_PORT}"
  run docker run -d --rm \
    --name yieldswarm-litellm-open-metal \
    -p "${LITELLM_HOST}:${LITELLM_PORT}:4000" \
    -e LOCAL_OLLAMA_BASE_URL \
    -e YIELDSWARM_ROUTER_API_KEY \
    -e RUNPOD_B200_VLLM_URL \
    -e RUNPOD_H200_VLLM_URL \
    -e RUNPOD_H100_VLLM_URL \
    -v "${LITELLM_CONFIG}:/app/config.yaml:ro" \
    "${image}" \
    --config /app/config.yaml --port 4000
}

start_pip_litellm() {
  step "Starting LiteLLM via pip on ${LITELLM_HOST}:${LITELLM_PORT}"
  if ! command -v litellm >/dev/null 2>&1; then
    run pip install 'litellm[proxy]' --quiet
  fi
  screen_start litellm_backplane bash -lc \
    "cd '${REPO_ROOT}' && litellm --config '${LITELLM_CONFIG}' --host '${LITELLM_HOST}' --port '${LITELLM_PORT}' >> '${LOG_DIR}/litellm.log' 2>&1"
}

main() {
  ensure_log_dir
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would start LiteLLM with ${LITELLM_CONFIG}"
    return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    start_docker_litellm || start_pip_litellm
  else
    start_pip_litellm
  fi

  wait_for_http "http://${LITELLM_HOST}:${LITELLM_PORT}/health" 60 || \
    warn "LiteLLM health check pending — see ${LOG_DIR}/litellm.log"
  log "LiteLLM backplane at http://${LITELLM_HOST}:${LITELLM_PORT}/v1"
}

main "$@"

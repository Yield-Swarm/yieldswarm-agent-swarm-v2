#!/usr/bin/env bash
# =============================================================================
# hotload_open_metal_llms.sh — Native multi-model Ollama + vLLM swarm engine
#
# Hotloads open-weight model shards on RunPod metal (H100/H200/B200) with a
# local Ollama backplane and LiteLLM load balancer on :4000.
#
# Usage:
#   ./scripts/inference/hotload_open_metal_llms.sh
#   ./scripts/inference/hotload_open_metal_llms.sh --dry-run
#   ./scripts/inference/hotload_open_metal_llms.sh --reset
#   ./scripts/inference/hotload_open_metal_llms.sh --skip-litellm
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

DRY_RUN=0
RESET=0
SKIP_LITELLM=0
SKIP_PULL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --reset) RESET=1; shift ;;
    --skip-litellm) SKIP_LITELLM=1; shift ;;
    --skip-pull) SKIP_PULL=1; shift ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown arg: $1" ;;
  esac
done

export DRY_RUN

reset_legacy_gateways() {
  if [[ "${RESET}" != "1" ]]; then
    return 0
  fi
  step "Clearing legacy API gateways and local model memory segments"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] pkill ollama/vllm/litellm"
    return 0
  fi
  pkill -f 'ollama serve' 2>/dev/null || true
  pkill -f 'vllm.entrypoints' 2>/dev/null || true
  pkill -f 'litellm' 2>/dev/null || true
  sleep 1
}

install_ollama_if_needed() {
  if command -v ollama >/dev/null 2>&1; then
    log "ollama found: $(ollama --version 2>/dev/null || echo ok)"
    return 0
  fi
  step "Installing Ollama"
  run bash -c 'curl -fsSL https://ollama.com/install.sh | sh'
}

start_ollama_backend() {
  step "Starting Ollama backend"
  export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"

  if [[ "${DRY_RUN}" == "0" ]] && curl -fsS "$(ollama_api_base)/api/tags" >/dev/null 2>&1; then
    log "Ollama already listening on ${OLLAMA_HOST}"
    return 0
  fi

  if [[ -f "${REPO_ROOT}/docker/entrypoint-ollama.sh" && "${DRY_RUN}" == "0" ]]; then
    screen_start ollama_backend bash -lc \
      "cd '${REPO_ROOT}' && OLLAMA_HOST='${OLLAMA_HOST}' OLLAMA_PULL_MODELS='' '${REPO_ROOT}/docker/entrypoint-ollama.sh' >> '${LOG_DIR}/ollama.log' 2>&1"
  else
    screen_start ollama_backend ollama serve
  fi

  wait_for_http "$(ollama_api_base)/api/tags" 120
  log "Ollama API ready at $(ollama_api_base)"
}

pull_ollama_shards() {
  if [[ "${SKIP_PULL}" == "1" ]]; then
    warn "skipping model pulls (--skip-pull)"
    return 0
  fi

  step "Hotloading Ollama model weights (pull, not interactive run)"
  ensure_log_dir

  mapfile -t MODELS < <(load_matrix_models)
  if [[ "${#MODELS[@]}" -eq 0 ]]; then
    MODELS=(deepseek-r1:32b qwen2.5-coder:32b llama3.3:70b phi4:14b)
  fi

  for MODEL in "${MODELS[@]}"; do
    log "Pulling shard: ${MODEL}"
    if [[ "${DRY_RUN}" == "1" ]]; then
      log "[dry-run] ollama pull ${MODEL}"
      continue
    fi
    if ! ollama pull "${MODEL}" >> "${LOG_DIR}/pull-${MODEL//[:\/]/_}.log" 2>&1; then
      warn "failed to pull ${MODEL} — continuing"
    fi
  done
}

start_litellm_backplane() {
  if [[ "${SKIP_LITELLM}" == "1" ]]; then
    warn "skipping LiteLLM backplane (--skip-litellm)"
    return 0
  fi
  run "${SCRIPT_DIR}/start-litellm-backplane.sh" ${DRY_RUN:+--dry-run}
}

print_vllm_remote_hints() {
  step "RunPod vLLM shard bootstrap (run on each GPU node)"
  cat <<EOF
  B200 (${RUNPOD_NODE_B200:-outdoor_tomato_impala}):
    CUDA_VISIBLE_DEVICES=0 python3 -m vllm.entrypoints.openai.api_server \\
      --model deepseek-ai/DeepSeek-R1-Distill-Llama-70B --port 8000

  H200 (${RUNPOD_NODE_H200:-single_amber_peafowl}):
    CUDA_VISIBLE_DEVICES=0 python3 -m vllm.entrypoints.openai.api_server \\
      --model Qwen/Qwen2.5-Coder-32B-Instruct --port 8001

  H100 (${RUNPOD_NODE_H100:-thick_salmon_goat}):
    CUDA_VISIBLE_DEVICES=0 python3 -m vllm.entrypoints.openai.api_server \\
      --model Qwen/Qwen2.5-7B-Instruct --port 8002

  Set env on master:
    RUNPOD_B200_VLLM_URL=http://<b200-host>:8000/v1
    RUNPOD_H200_VLLM_URL=http://<h200-host>:8001/v1
    RUNPOD_H100_VLLM_URL=http://<h100-host>:8002/v1
EOF
}

print_summary() {
  local port
  port="$(matrix_litellm_port)"
  cat <<EOF

================================================================
INFRASTRUCTURE ONLINE — open-source metal array
  Ollama loopback:  $(ollama_api_base)/api
  LiteLLM router:   http://127.0.0.1:${port}/v1
  Matrix config:    ${MATRIX_FILE}
  Logs:             ${LOG_DIR}

Verify:
  ./scripts/inference/verify-open-metal.sh
  nvidia-smi
  curl -s $(ollama_api_base)/api/tags | python3 -m json.tool
================================================================
EOF
}

main() {
  ensure_log_dir
  reset_legacy_gateways
  install_ollama_if_needed
  start_ollama_backend
  pull_ollama_shards
  start_litellm_backplane
  print_vllm_remote_hints
  print_summary
}

main "$@"

#!/usr/bin/env bash
# Bootstrap vLLM on a RunPod GPU worker (run ON the pod, not the master).
# Usage: ./scripts/inference/remote-vllm-bootstrap.sh --tier b200|h200|h100
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

TIER="h100"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier) TIER="${2:-}"; shift 2 ;;
    b200|B200|h200|H200|h100|H100) TIER="$1"; shift ;;
    *) die "usage: $0 [--tier] b200|h200|h100" ;;
  esac
done
case "${TIER}" in
  b200|B200)
    PORT=8000
    MODEL="${VLLM_MODEL:-deepseek-ai/DeepSeek-R1-Distill-Llama-70B}"
    GPU_UTIL="${VLLM_GPU_UTIL:-0.92}"
    ;;
  h200|H200)
    PORT=8001
    MODEL="${VLLM_MODEL:-Qwen/Qwen2.5-Coder-32B-Instruct}"
    GPU_UTIL="${VLLM_GPU_UTIL:-0.90}"
    ;;
  h100|H100)
    PORT=8002
    MODEL="${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct}"
    GPU_UTIL="${VLLM_GPU_UTIL:-0.88}"
    ;;
  *)
    die "usage: $0 --tier b200|h200|h100"
    ;;
esac

step "vLLM shard — ${TIER} port ${PORT} model ${MODEL}"

if ! python3 -c "import vllm" 2>/dev/null; then
  log "installing vllm..."
  pip install vllm --quiet
fi

export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
screen_start "vllm_${TIER}" python3 -m vllm.entrypoints.openai.api_server \
  --model "${MODEL}" \
  --port "${PORT}" \
  --host 0.0.0.0 \
  --gpu-memory-utilization "${GPU_UTIL}"

log "vLLM listening on :${PORT} — export RUNPOD_${TIER^^}_VLLM_URL=http://<this-host>:${PORT}/v1 on master"

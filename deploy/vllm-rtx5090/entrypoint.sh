#!/usr/bin/env bash
# vLLM RTX 5090 entrypoint — continuous batching + prefix caching
set -euo pipefail

MODEL_NAME="${MODEL_NAME:-Qwen/Qwen2.5-14B-Instruct-AWQ}"
QUANTIZATION="${VLLM_QUANTIZATION:-awq}"
GPU_UTIL="${VLLM_GPU_MEMORY_UTILIZATION:-0.92}"
MAX_LEN="${VLLM_MAX_MODEL_LEN:-8192}"
PORT="${VLLM_PORT:-8000}"
METRICS_PORT="${VLLM_METRICS_PORT:-9090}"

echo "[vllm-5090] model=${MODEL_NAME} quant=${QUANTIZATION} gpu_util=${GPU_UTIL}"

ARGS=(
  --model "${MODEL_NAME}"
  --host 0.0.0.0
  --port "${PORT}"
  --dtype auto
  --gpu-memory-utilization "${GPU_UTIL}"
  --enable-prefix-caching
  --max-model-len "${MAX_LEN}"
)

if [[ -n "${QUANTIZATION}" && "${QUANTIZATION}" != "none" ]]; then
  ARGS+=(--quantization "${QUANTIZATION}")
fi

# Prometheus metrics (vLLM exposes /metrics when enabled)
if [[ "${VLLM_ENABLE_METRICS:-1}" == "1" ]]; then
  ARGS+=(--enable-metrics)
fi

exec python3 -m vllm.entrypoints.openai.api_server "${ARGS[@]}"

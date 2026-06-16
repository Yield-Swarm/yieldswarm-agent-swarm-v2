#!/usr/bin/env bash
# deploy/entrypoint.bert.sh — vLLM launcher with continuous batching + AWQ on RTX 5090.
set -euo pipefail

MODEL_ID="${MODEL_ID:-meta-llama/Llama-3.1-8B-Instruct-AWQ}"
QUANTIZATION="${QUANTIZATION:-awq}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.92}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-1}"
PORT="${VLLM_PORT:-8000}"
HOST="${VLLM_HOST:-0.0.0.0}"

log() { printf '[bert-entrypoint] %s\n' "$*"; }

if command -v nvidia-smi >/dev/null 2>&1; then
  log "GPU detected:"
  nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || true
else
  log "WARN: nvidia-smi not found — CPU-only fallback may fail for AWQ models"
fi

# Start hardware monitor in background when workload is vLLM itself.
MONITOR_PID=""
if [[ -x /app/deploy/entrypoint.monitor.sh ]]; then
  :
elif [[ -x ./deploy/entrypoint.monitor.sh ]]; then
  ./deploy/entrypoint.monitor.sh $$ 10 &
  MONITOR_PID=$!
  log "hardware monitor pid=$MONITOR_PID"
fi

ARGS=(
  --model "$MODEL_ID"
  --host "$HOST"
  --port "$PORT"
  --max-model-len "$MAX_MODEL_LEN"
  --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION"
  --tensor-parallel-size "$TENSOR_PARALLEL_SIZE"
  --enable-chunked-prefill
  --max-num-batched-tokens 8192
)

if [[ -n "$QUANTIZATION" && "$QUANTIZATION" != "none" ]]; then
  ARGS+=(--quantization "$QUANTIZATION")
fi

log "starting vLLM: ${ARGS[*]}"
exec python3 -m vllm.entrypoints.openai.api_server "${ARGS[@]}"

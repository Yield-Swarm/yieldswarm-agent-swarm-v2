#!/usr/bin/env bash
# vLLM RTX 5090 entrypoint — continuous batching + tier-aware model selection.
set -Eeuo pipefail

MODEL="${VLLM_MODEL:-deepseek-ai/DeepSeek-R1-Distill-Llama-70B}"
HOST="${VLLM_HOST:-0.0.0.0}"
PORT="${VLLM_PORT:-8000}"
TENSOR_PARALLEL="${VLLM_TENSOR_PARALLEL:-1}"
GPU_MEMORY="${VLLM_GPU_MEMORY_UTILIZATION:-0.92}"
MAX_SEQS="${VLLM_MAX_NUM_SEQS:-64}"

log() { echo "[$(date -u +%FT%TZ)] [vllm-5090] $*" >&2; }

thermal_check() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    local temp
    temp="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || echo 0)"
    if [[ "${temp:-0}" -gt "${THERMAL_LIMIT_C:-83}" ]]; then
      log "WARN: GPU temp ${temp}C exceeds limit ${THERMAL_LIMIT_C:-83}C — throttling batch size"
      export VLLM_MAX_NUM_SEQS=$((MAX_SEQS / 2))
    fi
  fi
}

start_metrics() {
  python3 - <<'PY' &
import os, time
from prometheus_client import start_http_server, Gauge
port = int(os.environ.get("METRICS_PORT", "9090"))
g_temp = Gauge("yieldswarm_gpu_temp_c", "GPU temperature Celsius")
g_vram = Gauge("yieldswarm_vram_used_pct", "VRAM utilization percent")
start_http_server(port)
while True:
    try:
        import subprocess
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=temperature.gpu,utilization.memory", "--format=csv,noheader,nounits"],
            text=True,
        ).strip().split("\n")[0]
        temp, vram = out.split(", ")
        g_temp.set(float(temp))
        g_vram.set(float(vram))
    except Exception:
        pass
    time.sleep(15)
PY
}

main() {
  log "Starting vLLM on RTX 5090 — model=${MODEL} tp=${TENSOR_PARALLEL}"
  thermal_check
  start_metrics

  exec python3 -m vllm.entrypoints.openai.api_server \
    --model "${MODEL}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --tensor-parallel-size "${TENSOR_PARALLEL}" \
    --gpu-memory-utilization "${GPU_MEMORY}" \
    --max-num-seqs "${VLLM_MAX_NUM_SEQS:-${MAX_SEQS}}" \
    --enable-chunked-prefill \
    --max-model-len "${VLLM_MAX_MODEL_LEN:-32768}" \
    --served-model-name "${VLLM_SERVED_NAME:-yieldswarm-5090}"
}

main "$@"

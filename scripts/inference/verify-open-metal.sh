#!/usr/bin/env bash
# Verify open-metal inference cluster health.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

FAIL=0
LITELLM_PORT="$(matrix_litellm_port)"
LITELLM_HOST="${LLM_ROUTER_BIND:-127.0.0.1}"
OLLAMA_BASE="$(ollama_api_base)"

step "VRAM audit"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader || FAIL=1
else
  warn "nvidia-smi not found — skip GPU audit"
fi

step "Ollama model registry"
if curl -fsS "${OLLAMA_BASE}/api/tags" | python3 -m json.tool; then
  log "Ollama tags OK"
else
  warn "Ollama not reachable at ${OLLAMA_BASE}"
  FAIL=1
fi

step "LiteLLM router health"
if curl -fsS "http://${LITELLM_HOST}:${LITELLM_PORT}/health" >/dev/null 2>&1; then
  log "LiteLLM health OK"
  curl -fsS "http://${LITELLM_HOST}:${LITELLM_PORT}/v1/models" 2>/dev/null | python3 -m json.tool || true
else
  warn "LiteLLM not reachable at http://${LITELLM_HOST}:${LITELLM_PORT}"
  FAIL=1
fi

step "vLLM shard probes (optional RunPod endpoints)"
for label in B200 H200 H100; do
  var="RUNPOD_${label}_VLLM_URL"
  url="${!var:-}"
  [[ -z "${url}" ]] && continue
  base="${url%/v1}"
  if curl -fsS "${base}/health" >/dev/null 2>&1 || curl -fsS "${base}/v1/models" >/dev/null 2>&1; then
    log "${label} vLLM OK — ${url}"
  else
    warn "${label} vLLM unreachable — ${url}"
  fi
done

if [[ "${FAIL}" -ne 0 ]]; then
  die "verification failed — run ./scripts/inference/hotload_open_metal_llms.sh"
fi

log "open-metal verification passed"

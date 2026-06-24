#!/usr/bin/env bash
# Termux-native lightweight LLM — llama.cpp server (ARM, no nvidia-smi)
# Run ONLY on Termux/Android — NOT on RunPod GPU pods.
set -euo pipefail

log() { printf '[termux-llm] %s\n' "$*"; }

if [[ -z "${TERMUX_VERSION:-}" ]] && [[ ! -d /data/data/com.termux ]]; then
  log "WARN: not detected as Termux — use RunPod Ollama script instead"
fi

pkg update -y && pkg upgrade -y
pkg install -y clang cmake git curl wget proot-distro

LLAMA_DIR="${HOME}/llama.cpp"
MODEL_DIR="${HOME}/models"
MODEL_FILE="qwen2.5-coder-7b-instruct-q4_k_m.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf"

if [[ ! -d "${LLAMA_DIR}" ]]; then
  git clone https://github.com/ggerganov/llama.cpp "${LLAMA_DIR}"
fi

mkdir -p "${LLAMA_DIR}/build" "${MODEL_DIR}"
cd "${LLAMA_DIR}/build"
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j"$(nproc)" --target llama-server

if [[ ! -f "${MODEL_DIR}/${MODEL_FILE}" ]]; then
  log "Downloading ${MODEL_FILE} (~4GB)..."
  curl -L "${MODEL_URL}" -o "${MODEL_DIR}/${MODEL_FILE}"
fi

pkg install -y screen
pkill -f llama-server 2>/dev/null || true
screen -dmS termux_llm "${LLAMA_DIR}/build/bin/llama-server" \
  -m "${MODEL_DIR}/${MODEL_FILE}" \
  -c 2048 \
  --host 127.0.0.1 \
  --port 8080 \
  -t "$(nproc)"

log "Local LLM on http://127.0.0.1:8080/v1"
log "Test: curl http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' -d '{\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}'"

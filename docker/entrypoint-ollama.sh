#!/usr/bin/env bash
#
# Ollama GPU worker entrypoint for YieldSwarm Akash deployments.
#
# Boots `ollama serve` bound to all interfaces, waits until the HTTP API is
# ready, pulls a configurable set of models, then keeps the server in the
# foreground so the container/lease stays healthy.
#
# Configuration (all optional, sensible defaults):
#   OLLAMA_HOST          bind address for the server   (default 0.0.0.0:11434)
#   OLLAMA_PULL_MODELS   space/comma separated models  (default "llama3.1:8b qwen2.5:14b")
#   OLLAMA_PULL_TIMEOUT  seconds to wait for API ready  (default 120)
#
set -euo pipefail

OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0:11434}"
OLLAMA_PULL_MODELS="${OLLAMA_PULL_MODELS:-llama3.1:8b qwen2.5:14b}"
OLLAMA_PULL_TIMEOUT="${OLLAMA_PULL_TIMEOUT:-120}"
export OLLAMA_HOST

# The API is reachable locally on the same host:port the server binds to.
api_base="http://${OLLAMA_HOST/0.0.0.0/127.0.0.1}"

log() { printf '[entrypoint-ollama] %s\n' "$*" >&2; }

log "starting ollama serve on ${OLLAMA_HOST}"
ollama serve &
serve_pid=$!

# Forward termination signals so Akash/Docker can stop the lease cleanly.
trap 'log "stopping (signal received)"; kill -TERM "${serve_pid}" 2>/dev/null || true' TERM INT

# Wait for the HTTP API to accept connections before pulling models.
log "waiting up to ${OLLAMA_PULL_TIMEOUT}s for the Ollama API at ${api_base}"
ready=0
for _ in $(seq 1 "${OLLAMA_PULL_TIMEOUT}"); do
  if curl -fsS "${api_base}/api/tags" >/dev/null 2>&1; then
    ready=1
    break
  fi
  # If the server process died, fail fast instead of looping.
  if ! kill -0 "${serve_pid}" 2>/dev/null; then
    log "ollama serve exited before becoming ready"
    wait "${serve_pid}"
    exit 1
  fi
  sleep 1
done

if [ "${ready}" -ne 1 ]; then
  log "Ollama API did not become ready within ${OLLAMA_PULL_TIMEOUT}s"
  kill -TERM "${serve_pid}" 2>/dev/null || true
  exit 1
fi
log "Ollama API is ready"

# Pull the configured models (idempotent — already-present models are skipped).
# Accept either space- or comma-separated lists.
models="${OLLAMA_PULL_MODELS//,/ }"
for model in ${models}; do
  [ -n "${model}" ] || continue
  log "pulling model: ${model}"
  if ! ollama pull "${model}"; then
    # A single bad model name should not take down the whole worker.
    log "WARNING: failed to pull ${model}; continuing"
  fi
done

log "model preload complete; serving (pid ${serve_pid})"
# Hand control back to the long-running server process.
wait "${serve_pid}"

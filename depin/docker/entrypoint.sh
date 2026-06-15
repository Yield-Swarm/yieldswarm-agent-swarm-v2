#!/usr/bin/env bash
set -euo pipefail

HEARTBEAT_INTERVAL_SECONDS="${HEARTBEAT_INTERVAL_SECONDS:-420}"
LATENCY_GUARDRAIL_MS="${LATENCY_GUARDRAIL_MS:-80}"
WORKER_ROLE="${WORKER_ROLE:-openclaw-gpu}"
OLLAMA_PRIMARY_MODEL="${OLLAMA_PRIMARY_MODEL:-llama3.1:8b}"
OLLAMA_SECONDARY_MODEL="${OLLAMA_SECONDARY_MODEL:-qwen2.5:7b}"

echo "[worker] role=${WORKER_ROLE}"
echo "[worker] heartbeat_interval=${HEARTBEAT_INTERVAL_SECONDS}s"
echo "[worker] latency_guardrail_ms=${LATENCY_GUARDRAIL_MS}"
echo "[worker] warm_models=${OLLAMA_PRIMARY_MODEL},${OLLAMA_SECONDARY_MODEL}"

# Model warm-up hook: keep non-fatal until model server integration is wired.
if command -v ollama >/dev/null 2>&1; then
  ollama pull "${OLLAMA_PRIMARY_MODEL}" || true
  ollama pull "${OLLAMA_SECONDARY_MODEL}" || true
fi

exec python3 /opt/yieldswarm/api/great-delta/telemetry.py

#!/usr/bin/env bash
# Akash container entrypoint — RTX 5090 Ollama worker
# Auto-recovers Debian buster apt mirrors, starts Ollama, pulls models.
set -euo pipefail

log() { printf '[rtx5090-entrypoint] %s\n' "$*"; }

recover_apt_buster() {
  if [[ -f /etc/apt/sources.list ]] && grep -qE 'buster|archive\.debian\.org' /etc/apt/sources.list 2>/dev/null; then
    return 0
  fi
  if [[ ! -f /etc/debian_version ]]; then
    return 0
  fi
  log "Applying Debian buster archive mirror recovery"
  cat > /etc/apt/sources.list <<'EOF'
deb http://archive.debian.org/debian/ buster main
deb http://archive.debian.org/debian-security buster/updates main
EOF
  apt-get update -o Acquire::Check-Valid-Until=false || true
  apt-get install -y curl ca-certificates || true
}

start_ollama() {
  if ! command -v ollama &>/dev/null; then
    log "Installing Ollama"
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  export OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0:11434}"
  if ! pgrep -x ollama >/dev/null 2>&1; then
    log "Starting Ollama at ${OLLAMA_HOST}"
    nohup ollama serve >/var/log/ollama.log 2>&1 &
    sleep 3
  fi
}

pull_models() {
  local models="${OLLAMA_MODELS:-llama3.1:8b,qwen2.5:14b}"
  IFS=',' read -ra MODEL_LIST <<< "${models}"
  for model in "${MODEL_LIST[@]}"; do
    model="$(echo "${model}" | xargs)"
    [[ -n "${model}" ]] || continue
    log "Pulling ${model}"
    ollama pull "${model}" || log "WARN: failed to pull ${model}"
  done
}

start_telemetry() {
  local port="${TELEMETRY_PORT:-8080}"
  if [[ -f /opt/yieldswarm/agents/bittensor_telemetry_server.py ]]; then
    log "Starting telemetry on :${port}"
    python3 /opt/yieldswarm/agents/bittensor_telemetry_server.py &
    return
  fi
  # Minimal fallback — proxy Ollama /api/ps
  python3 - <<PY &
import json, time
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.request

PORT = int("${port}")

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/health", "/api/telemetry/5090"):
            self.send_response(404); self.end_headers(); return
        try:
            with urllib.request.urlopen("http://127.0.0.1:11434/api/ps", timeout=5) as r:
                body = r.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            self.send_response(503)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
    def log_message(self, *a): pass

HTTPServer(("0.0.0.0", PORT), H).serve_forever()
PY
}

recover_apt_buster
start_ollama
pull_models
start_telemetry

log "RTX 5090 worker ready — Ollama ${OLLAMA_HOST:-0.0.0.0:11434}"
wait -n

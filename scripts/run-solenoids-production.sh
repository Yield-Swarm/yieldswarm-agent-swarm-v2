#!/usr/bin/env bash
# scripts/run-solenoids-production.sh
# Boot Nexus + Helix + Shadow Chain on a production host (Azure VM, etc.)
#
# Usage (on server after SSH):
#   cd ~/yieldswarm-agent-swarm-v2
#   git fetch && git checkout cursor/solenoid-nexus-helix-shadow-4f85
#   ./scripts/run-solenoids-production.sh
#
# Env:
#   VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID  — live secret injection
#   PROVIDER=azure|akash|vastai                  — vault inject target
#   PORT=8080                                   — backend listen port
#   SKIP_VAULT=1                                — skip vault inject (dev)
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-8080}"
PROVIDER="${PROVIDER:-azure}"
LOG_DIR="${LOG_DIR:-$ROOT/.run}"
PID_FILE="${PID_FILE:-$LOG_DIR/backend.pid}"
SKIP_VAULT="${SKIP_VAULT:-0}"

log() { printf '[solenoids-run] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

mkdir -p "$LOG_DIR"

load_env() {
  if [[ -f deploy/config.env ]]; then
    set -a; source deploy/config.env; set +a
  fi
  if [[ -f .env ]]; then
    set -a; source .env; set +a
  fi
}

inject_secrets() {
  if [[ "$SKIP_VAULT" == "1" ]]; then
    log "SKIP_VAULT=1 — using existing env"
    return 0
  fi
  if [[ -x vault/inject/render-env.sh ]]; then
    log "injecting secrets provider=$PROVIDER"
    PROVIDER="$PROVIDER" AGENT_ENV_FILE="${AGENT_ENV_FILE:-/tmp/yieldswarm-agent.env}" \
      ./vault/inject/render-env.sh || log "vault inject failed — continuing with .env"
    if [[ -f "${AGENT_ENV_FILE:-/tmp/yieldswarm-agent.env}" ]]; then
      set -a; source "${AGENT_ENV_FILE:-/tmp/yieldswarm-agent.env}"; set +a
    fi
  fi
}

install_deps() {
  log "installing backend dependencies"
  (cd backend && npm ci --omit=dev 2>/dev/null || cd backend && npm install)
}

stop_backend() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      log "stopping backend pid=$pid"
      kill "$pid" 2>/dev/null || true
      sleep 1
    fi
    rm -f "$PID_FILE"
  fi
}

start_backend() {
  stop_backend
  log "starting integration backend on :$PORT"
  cd "$ROOT/backend"
  PORT="$PORT" nohup node src/server.js >> "$LOG_DIR/backend.log" 2>&1 &
  echo $! > "$PID_FILE"
  cd "$ROOT"
  sleep 2
}

wait_healthy() {
  local url="http://127.0.0.1:${PORT}/api/health"
  local i
  for i in $(seq 1 30); do
    if curl -sfS "$url" >/dev/null 2>&1; then
      log "backend healthy"
      return 0
    fi
    sleep 1
  done
  die "backend did not become healthy — tail $LOG_DIR/backend.log"
}

probe_solenoids() {
  local base="http://127.0.0.1:${PORT}"
  log "=== Solenoid health probes ==="

  curl -sfS "$base/api/nexus/status" | tee "$LOG_DIR/nexus-status.json" | head -c 400
  echo ""
  log "nexus OK"

  curl -sfS "$base/api/helix/treasury" | tee "$LOG_DIR/helix-treasury.json" | head -c 400
  echo ""
  log "helix OK"

  curl -sfS "$base/api/shadow/arena/status" | tee "$LOG_DIR/shadow-arena.json" | head -c 400
  echo ""
  log "shadow OK"

  curl -sfS -X POST "$base/api/helix/treasury/route" \
    -H 'Content-Type: application/json' \
    -d '{"grossLamports":1000000,"dryRun":true}' \
    | tee "$LOG_DIR/helix-route-dryrun.json" | head -c 400
  echo ""
  log "helix dry-run route OK"
}

main() {
  load_env
  inject_secrets
  install_deps
  start_backend
  wait_healthy
  probe_solenoids

  log "=== LIVE ==="
  log "Nexus:  http://$(hostname -I 2>/dev/null | awk '{print $1}'):${PORT}/api/nexus/status"
  log "Helix:  http://$(hostname -I 2>/dev/null | awk '{print $1}'):${PORT}/api/helix/treasury"
  log "Shadow: http://$(hostname -I 2>/dev/null | awk '{print $1}'):${PORT}/api/shadow/arena/status"
  log "Logs:   tail -f $LOG_DIR/backend.log"
  log "PID:    $(cat "$PID_FILE")"
}

main "$@"

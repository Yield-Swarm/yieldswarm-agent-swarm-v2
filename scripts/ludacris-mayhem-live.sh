#!/usr/bin/env bash
# scripts/ludacris-mayhem-live.sh
# Wire ALL live: 14 pillars · 3 solenoids · ZK Mayhem · command dashboard
#
# Usage:
#   ./scripts/ludacris-mayhem-live.sh              # telemetry + API wire (safe default)
#   LUDACRIS_TREASURY_LIVE=1 ./scripts/ludacris-mayhem-live.sh  # + live treasury routes
#
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LOG_DIR="$ROOT/.run/ludacris-mayhem"
mkdir -p "$LOG_DIR"

# shellcheck source=/dev/null
[[ -f config/ludacris-mayhem.env ]] && set -a && source config/ludacris-mayhem.env && set +a
[[ -f .env ]] && set -a && source .env && set +a
[[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a

export LUDACRIS_MAYHEM_MODE=1
export MAYHEM_MODE_ENABLED=true
export ZK_MAYHEM_ENABLED=1
export NETWORK_LOCKDOWN_MODE=false

API_BASE="${API_BASE:-http://127.0.0.1:${PORT:-8080}}"
TREASURY_LIVE="${LUDACRIS_TREASURY_LIVE:-0}"

if [[ "$TREASURY_LIVE" == "1" ]]; then
  export CROSS_CHAIN_DRY_RUN=0
  export MUTATION_ENGINE_DRY_RUN=0
  log_warn="TREASURY LIVE — real routes enabled"
else
  export CROSS_CHAIN_DRY_RUN=1
  log_warn="telemetry live · treasury dry-run (set LUDACRIS_TREASURY_LIVE=1 for on-chain)"
fi

log() { printf '[ludacris-mayhem] %s\n' "$*" | tee -a "$LOG_DIR/wire.log"; }

curl_json() {
  local method="$1" url="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sfS -X "$method" "$url" -H 'Content-Type: application/json' -d "$data" 2>>"$LOG_DIR/wire.log"
  else
    curl -sfS -X "$method" "$url" 2>>"$LOG_DIR/wire.log"
  fi
}

wait_api() {
  local i
  for i in $(seq 1 40); do
    if curl -sfS "$API_BASE/api/health" >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  return 1
}

start_backend() {
  if curl -sfS "$API_BASE/api/health" >/dev/null 2>&1; then
    log "backend already up at $API_BASE"
    return 0
  fi
  log "starting backend..."
  PORT="${PORT:-8080}" nohup node backend/src/server.js >> "$LOG_DIR/backend.log" 2>&1 &
  echo $! > "$LOG_DIR/backend.pid"
  wait_api || { log "backend failed to start"; return 1; }
}

wire_pillars() {
  local pillars=(
    "01_greek_vaults" "02_infra_oracles" "03_zk_mayhem_core" "04_akash_gpu_workers"
    "05_arena_leaderboard" "06_cross_chain_exec" "07_depin_orchestration" "08_emission_routing"
    "09_agentswarm_os" "10_security_tee_mpc" "11_telemetry_observability" "12_governance"
    "13_treasury_yield" "14_valhalla_portal"
  )
  local i name
  for i in "${!pillars[@]}"; do
    name="${pillars[$i]}"
    local id=$((i + 1))
    log "pillar $id/14 — $name"
    curl_json POST "$API_BASE/api/solenoid/pulse" \
      "{\"pillarId\":\"$id\",\"name\":\"$name\",\"metrics\":{\"gpu_temperature\":82,\"vram_used_bytes\":28000000000,\"tokens_per_sec\":1400}}" \
      >> "$LOG_DIR/pillar-${id}.json" || true
  done
}

wire_solenoids() {
  log "nexus init"
  curl_json GET "$API_BASE/api/nexus/status" >> "$LOG_DIR/nexus.json" || true

  log "helix treasury"
  curl_json GET "$API_BASE/api/helix/treasury" >> "$LOG_DIR/helix.json" || true

  local dry="true"
  [[ "$TREASURY_LIVE" == "1" ]] && dry="false"
  curl_json POST "$API_BASE/api/helix/treasury/route" \
    "{\"grossLamports\":1000000,\"dryRun\":$dry}" >> "$LOG_DIR/helix-route.json" || true

  log "shadow arena"
  curl_json GET "$API_BASE/api/shadow/arena/status" >> "$LOG_DIR/shadow.json" || true

  log "zk mayhem batch"
  curl_json POST "$API_BASE/api/helix/zk/batch" \
    '{"proofs":[{"proof":"0xmayhem","publicInputsHash":"0xludacris"}],"mutationRoot":"0xdeadbeef"}' \
    >> "$LOG_DIR/zk-batch.json" || true
}

wire_command() {
  log "command dashboard fuse"
  curl_json GET "$API_BASE/api/command/overview" >> "$LOG_DIR/command.json" || true
  curl_json POST "$API_BASE/api/command/mayhem/activate" \
    '{"source":"ludacris-mayhem-live.sh"}' >> "$LOG_DIR/mayhem-activate.json" || true
}

wire_matrix() {
  log "14-pillar axis matrix"
  curl_json POST "$API_BASE/api/solenoid/matrix" \
    '{"tenantId":"ludacris-mayhem","tier":1,"telemetry":{"gpu_temperature":79,"tokens_per_sec":1500}}' \
    >> "$LOG_DIR/matrix.json" || true
}

main() {
  log "══════════════════════════════════════════"
  log " LUDACRIS MAYHEM MODE — FULL WIRE LIVE"
  log " $log_warn"
  log "══════════════════════════════════════════"

  start_backend
  wire_pillars
  wire_solenoids
  wire_matrix
  wire_command

  log "DONE — open $API_BASE/command"
  log "health: $(curl -sfS "$API_BASE/api/command/health" 2>/dev/null || echo 'poll manually')"
}

main "$@"

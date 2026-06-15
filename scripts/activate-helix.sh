#!/usr/bin/env bash
# =============================================================================
# Helix Chain Activation — one-command genesis for YieldSwarm + Kairo stack.
#
# Usage:
#   ./scripts/activate-helix.sh              # full activation
#   ./scripts/activate-helix.sh --dry-run    # show plan only
#   ./scripts/activate-helix.sh --skip-loops # skip sovereign loop supervisor
#
# Sets HELIX_CHAIN_ENABLED=1, persists genesis receipt to dashboard/helix-state.json,
# starts sovereign loops, and probes /api/helix/status.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=false
SKIP_LOOPS=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-loops) SKIP_LOOPS=true ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

# shellcheck disable=SC1091
source "${REPO_ROOT}/deploy/scripts/lib.sh"
load_config

BACKEND_PORT="${PORT:-8080}"
BACKEND_URL="http://127.0.0.1:${BACKEND_PORT}"

step() { printf '\n==> %s\n' "$*"; }

if $DRY_RUN; then
  step "DRY RUN — Helix Chain activation plan"
  echo "  1. export HELIX_CHAIN_ENABLED=1"
  echo "  2. node backend adapter → activateHelixChain (genesis receipt)"
  echo "  3. deploy/scripts/start-sovereign-loops.sh start"
  echo "  4. curl ${BACKEND_URL}/api/helix/status"
  echo "  5. optional: git tag v1.0-helix-launch"
  exit 0
fi

step "1/5 Enable Helix Chain runtime flag"
export HELIX_CHAIN_ENABLED=1

step "2/5 Persist genesis receipt"
node --input-type=module <<'NODE'
import { activateHelixChain } from './backend/src/adapters/helix.js';

const result = await activateHelixChain({ source: 'activate-helix.sh', force: false });
console.log(JSON.stringify({
  ok: result.ok,
  genesisHash: result.genesisHash,
  alreadyActive: result.alreadyActive,
  phase: result.status?.phase,
  readinessScore: result.status?.readinessScore,
}, null, 2));
NODE

step "3/5 Start integration backend (if not running)"
helix_route_ok() {
  curl -sf "${BACKEND_URL}/api/helix/health" >/dev/null 2>&1
}

if helix_route_ok; then
  ok "backend with Helix routes already listening on ${BACKEND_PORT}"
else
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${BACKEND_PORT}/tcp" 2>/dev/null || true
    sleep 0.5
  elif [[ -f .run/backend.pid ]] && kill -0 "$(cat .run/backend.pid)" 2>/dev/null; then
    log "restarting backend to load Helix routes"
    kill "$(cat .run/backend.pid)" 2>/dev/null || true
    rm -f .run/backend.pid
    sleep 0.5
  fi
  if ! curl -sf "${BACKEND_URL}/api/health" >/dev/null 2>&1; then
    log "starting backend in background"
    mkdir -p .run
    HELIX_CHAIN_ENABLED=1 nohup node backend/src/server.js > .run/backend.log 2>&1 &
    echo $! > .run/backend.pid
  fi
  for _ in $(seq 1 30); do
    if helix_route_ok; then
      ok "backend up with Helix routes (pid $(cat .run/backend.pid 2>/dev/null || echo '?'))"
      break
    fi
    sleep 0.5
  done
  helix_route_ok || warn "Helix API not reachable — genesis receipt saved to dashboard/helix-state.json"
fi

step "4/5 Activate via API (idempotent) + start sovereign loops"
if helix_route_ok; then
  curl -sf -X POST "${BACKEND_URL}/api/helix/activate" \
    -H 'Content-Type: application/json' \
    -d '{"source":"activate-helix.sh"}' \
    | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{if(!d.trim()){console.log('(empty response)');return;}console.log(JSON.stringify(JSON.parse(d),null,2))})" \
    || warn "API activate returned non-zero (genesis may already be persisted)"
else
  warn "skipped API activate — offline genesis receipt already written in step 2"
fi

if ! $SKIP_LOOPS; then
  if [[ -x deploy/scripts/start-sovereign-loops.sh ]]; then
    bash deploy/scripts/start-sovereign-loops.sh start || warn "sovereign loops supervisor returned non-zero"
  else
    warn "start-sovereign-loops.sh not found — skip"
  fi
fi

step "5/5 Verify Helix Chain status"
if helix_route_ok; then
  curl -sf "${BACKEND_URL}/api/helix/status" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d);console.log('activated:',j.activated,'phase:',j.phase,'genesis:',j.genesisHash?.slice(0,16)+'…','readiness:',j.readinessScore)})"
else
  node --input-type=module -e "import { getHelixStatus } from './backend/src/adapters/helix.js'; const j=await getHelixStatus(); console.log('activated:',j.activated,'phase:',j.phase,'genesis:',j.genesisHash?.slice(0,16)+'…','readiness:',j.readinessScore)"
fi

echo ""
ok "Helix Chain activated. Council status: ${BACKEND_URL}/council/status"
echo "  Tag release: git tag -a v1.0-helix-launch -m 'Helix Chain activation'"

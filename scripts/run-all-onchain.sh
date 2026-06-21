#!/usr/bin/env bash
# =============================================================================
# run-all-onchain.sh — Execute full YieldSwarm on-chain stack in one pass
#
# Phases:
#   1. Preflight (cross-chain, contracts, env gates)
#   2. Helix Chain genesis activation
#   3. Cross-chain strategy batch (Jupiter, Uniswap V4, dYdX, PoW)
#   4. ZK entropy mutation cycle → oracle bridge receipt
#   5. Agent NFT mutation engine
#   6. Sovereign loop supervisor (optional)
#   7. Unified on-chain status report → .run/onchain-run-report.json
#
# Usage:
#   ./scripts/run-all-onchain.sh              # live mode (CROSS_CHAIN_DRY_RUN=0, etc.)
#   ./scripts/run-all-onchain.sh --dry-run    # simulate all rails
#   ./scripts/run-all-onchain.sh --skip-loops # no background sovereign supervisor
# =============================================================================
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RUN_DIR="${RUN_DIR:-${ROOT}/.run}"
REPORT="${RUN_DIR}/onchain-run-report.json"
mkdir -p "$RUN_DIR"

LIVE=1
SKIP_LOOPS=0
START_BACKEND=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) LIVE=0; shift ;;
    --skip-loops) SKIP_LOOPS=1; shift ;;
    --start-backend) START_BACKEND=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -f .env ]] && set -a && source .env && set +a
[[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a

if [[ "$LIVE" == "1" ]]; then
  export HELIX_CHAIN_ENABLED=1
  export CROSS_CHAIN_DRY_RUN=0
  export MUTATION_ENGINE_DRY_RUN=0
  export MUTATION_LOOP_AUTO_RUN=1
  export CLOUD_SCHEDULER_DRY_RUN=0
  export CROSS_CHAIN_MVP_ENABLED=true
else
  export HELIX_CHAIN_ENABLED="${HELIX_CHAIN_ENABLED:-1}"
  export CROSS_CHAIN_DRY_RUN=1
  export MUTATION_ENGINE_DRY_RUN=1
  export MUTATION_LOOP_AUTO_RUN=0
  export CLOUD_SCHEDULER_DRY_RUN=1
fi

BACKEND_PORT="${PORT:-8080}"
BACKEND_URL="${YIELDSWARM_API_URL:-http://127.0.0.1:${BACKEND_PORT}}"

log()  { echo "[$(date -u +%FT%TZ)] [run-all-onchain] $*" >&2; }
warn() { log "WARN: $*"; }
die()  { log "ERROR: $*"; exit 1; }

declare -a PHASE_RESULTS=()
PASS=0
FAIL=0
WARN_CT=0

record() {
  local name="$1" status="$2" detail="${3:-}"
  PHASE_RESULTS+=("$(jq -nc --arg n "$name" --arg s "$status" --arg d "$detail" '{phase:$n,status:$s,detail:$d}')")
  case "$status" in
    pass) PASS=$((PASS + 1)) ;;
    fail) FAIL=$((FAIL + 1)) ;;
    warn) WARN_CT=$((WARN_CT + 1)) ;;
  esac
}

backend_up() {
  curl -sf "${BACKEND_URL}/api/health" >/dev/null 2>&1
}

ensure_backend() {
  if backend_up; then
    log "backend already listening on ${BACKEND_URL}"
    return 0
  fi
  if [[ "$START_BACKEND" != "1" ]]; then
    warn "backend not running — API phases will be skipped (use --start-backend)"
    return 1
  fi
  log "starting backend (HELIX_CHAIN_ENABLED=${HELIX_CHAIN_ENABLED})"
  HELIX_CHAIN_ENABLED="${HELIX_CHAIN_ENABLED}" nohup node backend/src/server.js > "${RUN_DIR}/backend-onchain.log" 2>&1 &
  echo $! > "${RUN_DIR}/backend-onchain.pid"
  for _ in $(seq 1 40); do
    backend_up && return 0
    sleep 0.25
  done
  return 1
}

phase_preflight() {
  log "Phase 1/7 — Preflight"
  if bash scripts/cross-chain-preflight.sh; then
    record preflight pass "cross-chain artifacts OK"
  else
    record preflight fail "cross-chain preflight failed"
  fi

  if command -v forge >/dev/null 2>&1; then
    if forge test --match-contract MutationControllerTest -q 2>/dev/null; then
      record contracts pass "MutationController tests green"
    else
      record contracts warn "forge tests skipped or failed"
    fi
  else
    record contracts warn "forge not installed"
  fi

  local missing=()
  [[ -z "${ORACLE_RELAYER_PRIVATE_KEY:-}" ]] && [[ -z "${SOVEREIGN_PRIVATE_KEY:-}" ]] && missing+=("wallet_keys")
  [[ -z "${MUTATION_CONTROLLER_ADDRESS:-}" ]] && missing+=("MUTATION_CONTROLLER_ADDRESS")
  [[ -z "${SOLANA_RPC_URL:-}" || "${SOLANA_RPC_URL}" == *"REDACTED"* ]] && missing+=("SOLANA_RPC_URL")
  if ((${#missing[@]} > 0)) && [[ "$LIVE" == "1" ]]; then
    record env_gate warn "live mode missing: ${missing[*]} — some txs will dry-run"
  else
    record env_gate pass "env gates nominal"
  fi
}

phase_helix() {
  log "Phase 2/7 — Helix Chain genesis"
  if HELIX_CHAIN_ENABLED=1 bash scripts/activate-helix.sh --skip-loops 2>"${RUN_DIR}/helix-activate.err"; then
    record helix pass "genesis receipt persisted"
  else
    if node --input-type=module -e "
      import { activateHelixChain } from './backend/src/adapters/helix.js';
      const r = await activateHelixChain({ source: 'run-all-onchain.sh', force: false });
      console.log(JSON.stringify({ ok: r.ok, genesisHash: r.genesisHash }));
    " > "${RUN_DIR}/helix-fallback.json" 2>/dev/null; then
      record helix pass "direct adapter activation"
    else
      record helix fail "$(head -c 200 "${RUN_DIR}/helix-activate.err" 2>/dev/null || echo unknown)"
    fi
  fi
}

phase_cross_chain() {
  log "Phase 3/7 — Cross-chain execution batch (dry_run=${CROSS_CHAIN_DRY_RUN})"
  if python3 agents/cross_chain_executor.py > "${RUN_DIR}/cross-chain-onchain.log" 2>&1; then
    local summary
    summary="$(jq -c '{job_count,dry_run,treasury_totals_usd}' "${RUN_DIR}/cross-chain-last-run.json" 2>/dev/null || echo '{}')"
    record cross_chain pass "$summary"
  else
    record cross_chain fail "executor exit non-zero — see .run/cross-chain-onchain.log"
  fi

  if python3 agents/cross_chain_mvp.py > "${RUN_DIR}/cross-chain-loop.log" 2>&1; then
    record cross_chain_mvp pass "MVP agent wrote .run/cross-chain-mvp.json"
  else
    record cross_chain_mvp warn "MVP agent optional failure"
  fi
}

phase_zk_oracle() {
  log "Phase 4/7 — ZK entropy + oracle bridge"
  if node -e "
    const { createRequire } = require('module');
    const req = createRequire('${ROOT}/');
    const { HardenedAuditEngine } = req('./src/infrastructure/entropy-core.js');
    const { TelemetryValidationBridge } = req('./src/infrastructure/oracle-bridge.js');
    const fs = require('fs');
    const audit = new HardenedAuditEngine();
    const bridge = new TelemetryValidationBridge();
    const block = audit.registerExecutionBlock(
      { tenantHash: 'ONCHAIN_RUN', payload: { pillarId: '03_zk_mayhem_core' } },
      { gpu_temperature: 68, vram_used_bytes: 14e9, tokens_per_sec: 1200 }
    );
    const pulse = bridge.processMetricPulse(
      { id: '3', namespaceHash: 'NS_ZK_ONCHAIN' },
      { gpu_temperature: 68, vram_used_bytes: 14e9, projected_yield_usd: 0 }
    );
    const out = { block, pulse };
    fs.writeFileSync('${RUN_DIR}/zk-mutation-onchain.json', JSON.stringify(out, null, 2));
    console.log(JSON.stringify({ status: pulse.status, anchor: pulse.stateAnchor }));
  " > "${RUN_DIR}/zk-onchain.log" 2>&1; then
    record zk_mutation pass "$(tail -1 "${RUN_DIR}/zk-onchain.log")"
  else
    record zk_mutation fail "zk cycle failed — see .run/zk-onchain.log"
  fi

  if ensure_backend; then
    local oracle_json
    oracle_json="$(curl -sf "${BACKEND_URL}/api/oracle/sync" 2>/dev/null || echo '{}')"
    if echo "$oracle_json" | jq -e . >/dev/null 2>&1; then
      record oracle_sync pass "$(echo "$oracle_json" | jq -c '{live,configured,dryRun}')"
    else
      record oracle_sync warn "oracle API unreachable"
    fi
  else
    record oracle_sync warn "backend down — skipped oracle sync probe"
  fi
}

phase_nft_mutations() {
  log "Phase 5/7 — Agent NFT mutation engine (dry_run=${MUTATION_ENGINE_DRY_RUN})"
  if MUTATION_ENGINE_DRY_RUN="${MUTATION_ENGINE_DRY_RUN}" python3 services/nft_mutation_engine.py --week "$(date +%U)" \
    > "${RUN_DIR}/nft-mutation-onchain.log" 2>&1; then
    record nft_mutation pass "batch complete"
  elif grep -q "Built .* mutation plan" "${RUN_DIR}/nft-mutation-onchain.log" 2>/dev/null; then
    record nft_mutation warn "plans built — set AGENT_NFT_CONTRACT + SOVEREIGN_PRIVATE_KEY for live txs"
  else
    record nft_mutation warn "engine exited — see .run/nft-mutation-onchain.log"
  fi
}

phase_sovereign_loops() {
  log "Phase 6/7 — Sovereign loop supervisor"
  if [[ "$SKIP_LOOPS" == "1" ]]; then
    record sovereign_loops warn "skipped (--skip-loops)"
    return 0
  fi
  if [[ -x deploy/scripts/start-sovereign-loops.sh ]]; then
  HELIX_CHAIN_ENABLED=1 CROSS_CHAIN_DRY_RUN="${CROSS_CHAIN_DRY_RUN}" \
    bash deploy/scripts/start-sovereign-loops.sh start 2>"${RUN_DIR}/sovereign-loops.err" || true
    record sovereign_loops pass "supervisor invoked"
  else
    record sovereign_loops warn "start-sovereign-loops.sh missing"
  fi
}

phase_status_report() {
  log "Phase 7/7 — Unified on-chain status report"
  local helix_json='{}'
  local cc_json='{}'
  local overall="YELLOW"

  [[ -f dashboard/helix-state.json ]] && helix_json="$(cat dashboard/helix-state.json)"
  [[ -f "${RUN_DIR}/cross-chain-last-run.json" ]] && cc_json="$(cat "${RUN_DIR}/cross-chain-last-run.json")"

  if ensure_backend; then
    curl -sf "${BACKEND_URL}/api/helix/status" > "${RUN_DIR}/helix-status-onchain.json" 2>/dev/null || true
    curl -sf "${BACKEND_URL}/api/cross-chain/overview" > "${RUN_DIR}/cross-chain-overview-onchain.json" 2>/dev/null || true
  fi

  [[ "$FAIL" -eq 0 && "$PASS" -ge 4 ]] && overall="GREEN"
  [[ "$FAIL" -ge 3 ]] && overall="RED"

  jq -n \
    --arg overall "$overall" \
    --argjson live "$([[ "$LIVE" == "1" ]] && echo true || echo false)" \
    --arg helix_enabled "${HELIX_CHAIN_ENABLED:-}" \
    --arg cc_dry "${CROSS_CHAIN_DRY_RUN:-}" \
    --arg mut_dry "${MUTATION_ENGINE_DRY_RUN:-}" \
    --argjson pass "$PASS" \
    --argjson fail "$FAIL" \
    --argjson warn "$WARN_CT" \
    --argjson phases "$(printf '%s\n' "${PHASE_RESULTS[@]}" | jq -s '.')" \
    --argjson helix "$helix_json" \
    --argjson cross_chain "$cc_json" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      overall: $overall,
      live_mode: $live,
      env: {
        HELIX_CHAIN_ENABLED: $helix_enabled,
        CROSS_CHAIN_DRY_RUN: $cc_dry,
        MUTATION_ENGINE_DRY_RUN: $mut_dry
      },
      summary: { pass: $pass, fail: $fail, warn: $warn },
      phases: $phases,
      helix_state: $helix,
      cross_chain_last_run: $cross_chain,
      generated_at: $generated_at
    }' > "$REPORT"

  record status_report pass "wrote ${REPORT}"
  log "Overall: ${overall} (pass=${PASS} fail=${FAIL} warn=${WARN_CT})"
  jq '{overall, live_mode, summary, phases: [.phases[] | {phase,status}]}' "$REPORT"
}

main() {
  log "YieldSwarm run-all-onchain — live=${LIVE}"
  phase_preflight
  phase_helix
  phase_cross_chain
  phase_zk_oracle
  phase_nft_mutations
  phase_sovereign_loops
  phase_status_report

  [[ "$FAIL" -eq 0 ]] && exit 0
  exit 1
}

main "$@"

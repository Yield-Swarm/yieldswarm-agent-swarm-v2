#!/usr/bin/env bash
# deploy/deploy-full-stack.sh
# Phase-ordered full-stack deployment harness (D → A → C → B).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PHASE="${PHASE:-all}"
DRY_RUN="${DRY_RUN:-0}"
TARGET_ENV="${TARGET_ENV:-devnet}"
SKIP_VAULT="${SKIP_VAULT:-0}"

usage() {
  cat <<'EOF'
Usage: deploy-full-stack.sh [--phase N|all] [--dry-run]

Phases (see docs/DEPLOYMENT_PRIORITY.md):
  1  Foundation: Vault, storage, DNS
  2  Core infra: multi-cloud, LLM router, ZK entropy, sovereign
  3  Applications: TON, Kairo, NFT, Arena
  4  Hardening: mesh, monitoring, security, E2E
  all  Run phases 1–4 sequentially

Environment:
  TARGET_ENV   devnet | testnet | production (default: devnet)
  DRY_RUN=1    Print commands without executing deploys
  SKIP_VAULT=1 Skip Vault seed check (local dev only)

EOF
}

log()  { printf '[deploy] %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }

load_env() {
  if [[ -f deploy/config.env ]]; then
    set -a; # shellcheck disable=SC1091
    source deploy/config.env; set +a
  fi
  if [[ -f .env ]]; then
    set -a; # shellcheck disable=SC1091
    source .env; set +a
  elif [[ -f deploy/env/layered.env.example ]]; then
    warn_once=1
    log "No .env found — copy deploy/env/layered.env.example to .env and fill secrets"
  fi
  export TARGET_ENV
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] $*"
  else
    log "$*"
    eval "$@"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

check_vault() {
  if [[ "$SKIP_VAULT" == "1" ]]; then
    log "SKIP_VAULT=1 — skipping Vault checks"
    return 0
  fi
  if [[ -z "${VAULT_ADDR:-}" ]]; then
    echo "VAULT_ADDR not set. Seed Vault first or set SKIP_VAULT=1 for local dev." >&2
    exit 1
  fi
  if [[ -n "${VAULT_TOKEN:-}" ]] && command -v vault >/dev/null 2>&1; then
    vault status >/dev/null 2>&1 || {
      echo "Vault unreachable at $VAULT_ADDR" >&2
      exit 1
    }
    log "Vault OK: $VAULT_ADDR"
  else
    log "VAULT_TOKEN not set — will rely on AppRole at runtime"
  fi
}

render_templates() {
  step "Rendering plug-and-play templates"
  chmod +x deploy/templates/lib/render-template.sh
  run "./deploy/templates/lib/render-template.sh all"
}

phase_1_foundation() {
  step "Phase 1: Foundation (Vault + storage + DNS)"
  check_vault
  if [[ -n "${VAULT_TOKEN:-}" ]] && [[ -f vault/scripts/seed-secrets.sh ]]; then
    run "./vault/scripts/seed-secrets.sh"
  fi
  if [[ -f deploy/scripts/validate-config.sh ]]; then
    run "./deploy/scripts/validate-config.sh"
  fi
  log "Phase 1 complete — verify DNS (Cloudflare) and storage (Neon/IPFS/Pinata) manually"
}

phase_2_core() {
  step "Phase 2: Core infrastructure"
  render_templates

  if [[ -f circuits/package.json ]]; then
    step "ZK circuit build (if circom installed)"
    if command -v circom >/dev/null 2>&1; then
      run "cd circuits && npm install --no-fund --no-audit && npm run build"
    else
      log "circom not installed — skip circuit build (see docs/ZK_ENTROPY_SETUP.md)"
    fi
  fi

  step "LLM router stack"
  if [[ -f deploy/rendered/llm-router/docker-compose.yml ]]; then
    run "docker compose -f deploy/rendered/llm-router/docker-compose.yml config >/dev/null"
  fi

  step "Akash backend template validation"
  if [[ -f deploy/rendered/cloud/akash/backend.sdl.yml ]]; then
    log "Rendered SDL: deploy/rendered/cloud/akash/backend.sdl.yml"
  fi

  if [[ -f scripts/start-sovereign-loops.sh ]]; then
    run "./scripts/start-sovereign-loops.sh" || true
  fi

  log "Phase 2 complete"
}

phase_3_applications() {
  step "Phase 3: Application layers"

  if [[ -f backend/package.json ]]; then
    step "Backend + Helix tests"
    run "npm run test:helix --if-present"
    run "cd backend && npm test"
  fi

  step "14-pillar validation"
  if [[ -f scripts/deploy-and-test-pillars.sh ]]; then
  run "API_BASE=${API_BASE:-http://127.0.0.1:8080} ./scripts/deploy-and-test-pillars.sh $TARGET_ENV" || true
  fi

  log "Phase 3 complete — deploy NFT contracts separately (forge script)"
}

phase_4_hardening() {
  step "Phase 4: Integration & hardening"

  if [[ -f deploy/monitoring/docker-compose.yml ]]; then
    run "docker compose -f deploy/monitoring/docker-compose.yml config >/dev/null" || true
  fi

  if [[ -f scripts/master-smoke-test.sh ]]; then
    run "./scripts/master-smoke-test.sh" || true
  fi

  if [[ -f scripts/verify-vault-injection.sh ]]; then
    run "./scripts/verify-vault-injection.sh" || true
  fi

  log "Phase 4 complete"
}

phase_mining() {
  step "Mining mode: OpenClaw pure-credit arbitrage"
  render_templates
  run "chmod +x deploy/deploy-openclaw-test.sh deploy/full-stack-mining-scale.sh scripts/profitability-tracker-pure-credit.sh deploy/templates/cloud/vast/deploy.sh"
  if [[ "${MINING_BUILD_IMAGE:-0}" == "1" ]] && command -v docker >/dev/null 2>&1; then
    run "docker build -f deploy/Dockerfile.openclaw -t ${OPENCLAW_IMAGE:-ghcr.io/yield-swarm/openclaw-miner:latest} ."
  fi
  if [[ "${MINING_TEST_DEPLOY:-0}" == "1" ]]; then
    run "./deploy/deploy-openclaw-test.sh"
  fi
  run "./scripts/profitability-tracker-pure-credit.sh"
  log "Mining phase complete — see docs/MINING_ARBITRAGE.md"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --phase) PHASE="$2"; shift 2 ;;
      --mining) PHASE="mining"; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
    esac
  done
}

main() {
  parse_args "$@"
  load_env

  echo "================================================================="
  echo "YIELDSWARM FULL-STACK DEPLOY — TARGET_ENV=$TARGET_ENV PHASE=$PHASE"
  echo "================================================================="

  case "$PHASE" in
    1) phase_1_foundation ;;
    2) phase_2_core ;;
    3) phase_3_applications ;;
    4) phase_4_hardening ;;
    mining) phase_mining ;;
    all)
      phase_1_foundation
      phase_2_core
      phase_3_applications
      phase_4_hardening
      ;;
    *)
      echo "Invalid phase: $PHASE" >&2
      usage
      exit 1
      ;;
  esac

  echo "================================================================="
  echo "DEPLOY HARNESS FINISHED — see docs/DEPLOYMENT_PRIORITY.md"
  echo "================================================================="
}

main "$@"

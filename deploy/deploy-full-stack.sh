#!/usr/bin/env bash
# deploy/deploy-full-stack.sh — Phase-ordered plug-and-play full stack deploy
#
# Usage:
#   bash deploy/deploy-full-stack.sh                 # all phases
#   bash deploy/deploy-full-stack.sh --phase 1       # foundation only
#   bash deploy/deploy-full-stack.sh --phase 2-3     # core + apps
#   bash deploy/deploy-full-stack.sh --dry-run
#   bash deploy/deploy-full-stack.sh --render-only   # render templates to deploy/rendered/
#
# Env: .env or config/layered.env.example (copy first)
# Docs: docs/DEPLOYMENT_PRIORITY_ORDER.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PHASE_START=1
PHASE_END=4
DRY_RUN=false
RENDER_ONLY=false
ENV_FILE="${ENV_FILE:-.env}"

log()  { echo "[deploy-full-stack] $*" >&2; }
warn() { echo "[deploy-full-stack] WARN: $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --render-only) RENDER_ONLY=true; shift ;;
    --phase)
      shift
      if [[ "${1:-}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        PHASE_START="${BASH_REMATCH[1]}"
        PHASE_END="${BASH_REMATCH[2]}"
      elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
        PHASE_START="$1"
        PHASE_END="$1"
      fi
      shift
      ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) warn "unknown arg: $1"; shift ;;
  esac
done

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  log "loaded $ENV_FILE"
else
  warn "missing $ENV_FILE — copy config/layered.env.example .env"
fi

run() {
  if $DRY_RUN; then
    log "[dry-run] $*"
  else
    log "→ $*"
    "$@"
  fi
}

render_templates() {
  local out="$REPO_ROOT/deploy/rendered"
  mkdir -p "$out/cloud/akash" "$out/cloud/azure" "$out/llm-router" "$out/zk-entropy" "$out/ton-kairo"
  export OLLAMA_IMAGE="${OLLAMA_IMAGE:-ollama/ollama:latest}"
  export OLLAMA_PULL_MODELS="${OLLAMA_PULL_MODELS:-llama3.1:8b,qwen2.5:14b}"
  export OLLAMA_PULL_TIMEOUT="${OLLAMA_PULL_TIMEOUT:-180}"
  export AKASH_CPU_UNITS="${AKASH_CPU_UNITS:-4}"
  export AKASH_MEMORY="${AKASH_MEMORY:-16Gi}"
  export AKASH_STORAGE="${AKASH_STORAGE:-50Gi}"
  export AKASH_GPU_MODEL="${AKASH_GPU_MODEL:-rtx4090}"
  export AKASH_PRICE_UAKT="${AKASH_PRICE_UAKT:-50000}"
  export AKASH_DEPLOY_COUNT="${AKASH_DEPLOY_COUNT:-1}"
  export TF_CLOUD_ORGANIZATION="${TF_CLOUD_ORGANIZATION:-HelixChainProd}"
  export TF_WORKSPACE="${TF_WORKSPACE:-Helixchainprod}"
  export ENABLE_AZURE_FALLBACK="${ENABLE_AZURE_FALLBACK:-true}"
  export AZURE_RESOURCE_GROUP_NAME="${AZURE_RESOURCE_GROUP_NAME:-yieldswarm-fallback-rg}"
  export AZURE_LOCATION="${AZURE_LOCATION:-eastus}"

  _render_one() {
    local tpl="$1" dest="$2"
    if command -v envsubst >/dev/null 2>&1; then
      envsubst < "$tpl" > "$dest"
    else
      python3 - "$tpl" "$dest" <<'PY'
import os, re, sys
tpl, dest = sys.argv[1], sys.argv[2]
text = open(tpl, encoding="utf-8").read()
def repl(m):
    key = m.group(1)
    if ":-" in key:
        name, default = key.split(":-", 1)
        return os.environ.get(name, default)
    return os.environ.get(key, m.group(0))
open(dest, "w", encoding="utf-8").write(re.sub(r"\$\{([^}]+)\}", repl, text))
PY
    fi
  }

  _render_one deploy/templates/cloud/akash/ollama-worker.sdl.yml.tpl "$out/cloud/akash/ollama-worker.sdl.yml"
  _render_one deploy/templates/cloud/azure/tfc-workspace.env.tpl "$out/cloud/azure/tfc-workspace.env"
  _render_one deploy/templates/llm-router/litellm.config.yaml.tpl "$out/llm-router/litellm.config.yaml"
  _render_one deploy/templates/zk-entropy/scheduler.env.tpl "$out/zk-entropy/scheduler.env"
  _render_one deploy/templates/ton-kairo/stack.env.tpl "$out/ton-kairo/stack.env"
  log "rendered templates → deploy/rendered/"
}

phase_1_foundation() {
  log "=== Phase 1: Foundation ==="
  run bash scripts/akash-preflight.sh || warn "akash preflight skipped"
  if [[ -n "${VAULT_TOKEN:-}" ]]; then
    run bash scripts/deploy-production.sh vault
  else
    warn "VAULT_TOKEN unset — skip vault bootstrap"
  fi
  if [[ -n "${DATABASE_URL:-}" ]]; then
    run python3 -m services.neon_store --migrate || warn "neon migrate skipped"
  fi
  render_templates
}

phase_2_core() {
  log "=== Phase 2: Core Infrastructure ==="
  if [[ "${ENABLE_AZURE_FALLBACK:-false}" == "true" ]] && [[ -n "${TF_CLOUD_ORGANIZATION:-}" ]]; then
    run make tfc-init || warn "tfc-init skipped"
    run make tfc-apply || warn "tfc-apply skipped"
  fi
  run make build || warn "build skipped"
  run make sovereign-up || warn "sovereign loops skipped"
  if [[ -f deploy/rendered/llm-router/litellm.config.yaml ]]; then
    log "LLM router config at deploy/rendered/llm-router/litellm.config.yaml"
  fi
}

phase_3_apps() {
  log "=== Phase 3: Application Layers ==="
  run bash scripts/run-mandelbrot-bot.sh || warn "mandelbrot bot skipped"
  if [[ -f deploy/rendered/cloud/akash/ollama-worker.sdl.yml ]]; then
    log "Akash SDL ready: deploy/rendered/cloud/akash/ollama-worker.sdl.yml"
    log "Deploy: provider-services tx deployment create deploy/rendered/cloud/akash/ollama-worker.sdl.yml --from <wallet>"
  fi
  run make frontend || warn "frontend build skipped"
}

phase_4_hardening() {
  log "=== Phase 4: Integration & Hardening ==="
  run make monitoring-up || warn "monitoring skipped"
  run npm run test:unit || warn "vitest failed"
  run bash -c 'cd backend && npm test' || warn "backend tests failed"
  run bash tests/integration/smoke_test.sh || warn "smoke test skipped (backend may be down)"
  if [[ -f scripts/sync-environment-branches.sh ]]; then
    run bash scripts/sync-environment-branches.sh || warn "env branch sync skipped"
  fi
}

render_templates

if $RENDER_ONLY; then
  log "render-only complete"
  exit 0
fi

for p in $(seq "$PHASE_START" "$PHASE_END"); do
  case "$p" in
    1) phase_1_foundation ;;
    2) phase_2_core ;;
    3) phase_3_apps ;;
    4) phase_4_hardening ;;
  esac
done

log "deploy-full-stack complete (phases ${PHASE_START}-${PHASE_END})"

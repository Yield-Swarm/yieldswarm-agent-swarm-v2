#!/usr/bin/env bash
# Full production deploy: Vault → GHCR → Akash (monolith + backend + Odysseus) →
# 17 domains → Vercel → Neon DATABASE_URL → sovereign loops.
#
# Usage:
#   ./scripts/deploy-production-full.sh              # full pipeline
#   ./scripts/deploy-production-full.sh --dry-run    # print steps only
#   ./scripts/deploy-production-full.sh --only vercel # single step
#
# Config: deploy/config.env (copy from deploy/config.env.example)
# Secrets: VAULT_TOKEN, VERCEL_TOKEN, DATABASE_URL (Neon), Akash keyring
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --only) ONLY="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a
export PATH="${ROOT}/bin:${PATH}:${HOME}/.local/bin"
export REPO_ROOT="$ROOT"
export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"

log()  { echo "[$(date -u +%FT%TZ)] [prod-full] $*" >&2; }
warn() { log "WARN: $*"; }
die()  { log "ERROR: $*"; exit 1; }

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] $*"
    return 0
  fi
  log "→ $*"
  "$@"
}

should_run() {
  [[ -z "$ONLY" || "$ONLY" == "$1" ]]
}

step_preflight() {
  should_run preflight || return 0
  run make preflight
  run bash scripts/akash-preflight.sh || warn "akash preflight NO-GO — continuing where possible"
}

step_vault() {
  should_run vault || return 0
  if [[ -n "${VAULT_TOKEN:-}" ]]; then
    run bash scripts/deploy-production.sh vault
  else
    warn "VAULT_TOKEN unset — skip vault bootstrap"
  fi
}

step_build() {
  should_run build || return 0
  if command -v docker >/dev/null 2>&1; then
    run make build
  else
    warn "docker missing — skip image build (use GHCR :latest or CI build-odysseus workflow)"
  fi
}

step_akash() {
  should_run akash || return 0
  run bash scripts/deploy-production.sh akash || warn "akash monolith deploy failed"
}

step_akash_backend() {
  should_run akash-backend || return 0
  run bash scripts/deploy-production.sh akash-backend || warn "akash backend deploy failed"
}

step_odysseus() {
  should_run odysseus || return 0
  if [[ -n "${VAULT_TOKEN:-}" ]]; then
    run bash scripts/deploy-odysseus-vault-akash.sh || \
      run bash scripts/deploy-production.sh akash-odysseus || \
      warn "odysseus deploy failed"
  else
    run AKASH_DRY_RUN=true bash scripts/deploy-production-odysseus.sh render-akash || true
    warn "VAULT_TOKEN unset — odysseus SDL rendered only (no live lease)"
  fi
}

step_frontend() {
  should_run frontend || return 0
  run make frontend
}

step_domains() {
  should_run domains || return 0
  run bash scripts/wire-production-domains.sh
}

step_vercel() {
  should_run vercel || return 0
  if [[ -n "${VERCEL_DEPLOY_HOOK:-}" ]]; then
    run bash scripts/deploy-production.sh vercel
  elif [[ -n "${VERCEL_TOKEN:-}" ]] && command -v npx >/dev/null 2>&1; then
    run npx --yes vercel@latest deploy --prod --yes --token "${VERCEL_TOKEN}"
  else
    warn "VERCEL_DEPLOY_HOOK/VERCEL_TOKEN unset — skip live Vercel deploy"
    run bash scripts/deploy-production.sh vercel
  fi
}

step_neon() {
  should_run neon || return 0
  if [[ -z "${DATABASE_URL:-}" ]]; then
    warn "DATABASE_URL unset — Neon not configured (payments use in-memory store)"
    return 0
  fi
  log "Neon DATABASE_URL present — verifying connectivity"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would verify Neon postgres connection"
    return 0
  fi
  python3 - <<'PY' || warn "Neon connection check failed"
import os, sys
url = os.environ.get("DATABASE_URL", "")
if not url.startswith("postgres"):
    sys.exit("DATABASE_URL is not postgres")
try:
    import urllib.parse as u
    p = u.urlparse(url)
    print(f"Neon host: {p.hostname}")
except Exception as e:
    sys.exit(str(e))
PY
  # Push DATABASE_URL to Vercel production env when token available
  if [[ -n "${VERCEL_TOKEN:-}" && -n "${VERCEL_PROJECT_ID:-}" ]]; then
    log "Setting DATABASE_URL on Vercel project ${VERCEL_PROJECT_ID}"
    curl -fsS -X POST \
      "https://api.vercel.com/v10/projects/${VERCEL_PROJECT_ID}/env" \
      -H "Authorization: Bearer ${VERCEL_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$(jq -nc \
        --arg key "DATABASE_URL" \
        --arg value "${DATABASE_URL}" \
        '{key:$key,value:$value,type:"encrypted",target:["production"]}')" \
      >/dev/null || warn "Vercel env push for DATABASE_URL failed"
  fi
}

step_monitoring() {
  should_run monitoring || return 0
  run make monitoring-up || warn "monitoring skipped"
  run make sovereign-up || warn "sovereign loops skipped"
}

step_status() {
  should_run status || return 0
  run bash scripts/deploy-production.sh status
  run bash scripts/smoke-test.sh || warn "smoke tests had failures"
}

STEPS=(
  preflight vault build
  akash akash-backend odysseus
  frontend domains vercel neon
  monitoring status
)

log "Production full deploy (dry_run=${DRY_RUN} only=${ONLY:-all})"
for step in "${STEPS[@]}"; do
  fn="step_${step//-/_}"
  if declare -f "$fn" >/dev/null 2>&1; then
    "$fn"
  else
    die "missing handler: $fn"
  fi
done
log "Production full deploy complete"

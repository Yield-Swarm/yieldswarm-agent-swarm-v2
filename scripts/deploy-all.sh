#!/usr/bin/env bash
# =============================================================================
# scripts/deploy-all.sh — Unified multi-platform YieldSwarm deployment
#
# Idempotent, safe to re-run. Delegates to scripts/deploy-production.sh and
# platform-specific targets.
#
# Usage:
#   ./scripts/deploy-all.sh                    # full stack (vault skip if no token)
#   ./scripts/deploy-all.sh vercel             # Vercel only
#   ./scripts/deploy-all.sh render             # Render blueprint hint / API
#   ./scripts/deploy-all.sh akash              # Akash Vault-injected monolith
#   ./scripts/deploy-all.sh akash-bittensor    # Bittensor miner (BT_NETUID required)
#   ./scripts/deploy-all.sh --dry-run          # print steps only
#   ./scripts/deploy-all.sh --from akash       # resume from step
#
# Config: deploy/config.env (copy from deploy/config.env.example)
# =============================================================================
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0
FROM_STEP=""
ONLY=""
TARGET="all"

log()  { echo "[$(date -u +%FT%TZ)] [deploy-all] $*" >&2; }
warn() { echo "[$(date -u +%FT%TZ)] [deploy-all] WARN: $*" >&2; }
die()  { echo "[$(date -u +%FT%TZ)] [deploy-all] ERROR: $*" >&2; exit 1; }

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --from)    FROM_STEP="$2"; shift 2 ;;
    --only)    ONLY="$2"; shift 2 ;;
    -h|--help) usage ;;
    all|vault|vercel|render|akash|akash-bittensor|akash-odysseus|akash-backend|terraform|azure|frontend|status)
      TARGET="$1"; shift ;;
    *) die "unknown arg: $1 (try --help)" ;;
  esac
done

[[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a
export REPO_ROOT="$ROOT" DRY_RUN

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would run: $*"
    return 0
  fi
  log "→ $*"
  "$@"
}

step_preflight() { run make preflight; }

step_vault() {
  if [[ -n "${VAULT_TOKEN:-}" ]]; then
    run bash scripts/deploy-production.sh vault
  else
    warn "VAULT_TOKEN unset — skipping vault bootstrap"
  fi
}

step_build() { run make build; }

step_vercel() {
  if command -v vercel >/dev/null 2>&1; then
    run vercel deploy --prod --yes 2>/dev/null || run bash scripts/deploy-production.sh vercel
  else
    run bash scripts/deploy-production.sh vercel
  fi
}

step_render() {
  if [[ -n "${RENDER_API_KEY:-}" && -n "${RENDER_SERVICE_ID:-}" ]]; then
    run bash deploy/terraform/scripts/deploy-render.sh 2>/dev/null || warn "render API deploy skipped"
  else
    run bash scripts/deploy-production.sh render
  fi
}

step_akash() {
  export USE_VAULT_AKASH="${USE_VAULT_AKASH:-1}"
  run bash scripts/deploy-production.sh akash
  run bash deploy/akash/auto-heal.sh --daemon 2>/dev/null || warn "auto-heal daemon skipped"
}

step_frontend() { run make frontend; }

step_terraform() { run make terraform-apply || warn "terraform apply skipped"; }

step_monitoring() {
  run make monitoring-up
  run make sovereign-up || warn "sovereign loops skipped"
}

step_status() {
  run bash scripts/deploy-production.sh status
  run bash scripts/smoke-test.sh 2>/dev/null || warn "smoke tests skipped"
}

deploy_target() {
  case "$TARGET" in
    all)
      local steps=(preflight vault build vercel render akash frontend terraform monitoring status)
      local i start=0
      if [[ -n "$FROM_STEP" ]]; then
        for i in "${!steps[@]}"; do
          [[ "${steps[$i]}" == "$FROM_STEP" ]] && start=$i && break
        done
      fi
      for i in "${!steps[@]}"; do
        [[ $i -lt $start ]] && continue
        [[ -n "$ONLY" && "${steps[$i]}" != "$ONLY" ]] && continue
        "step_${steps[$i]}"
      done
      ;;
    vault|vercel|render|akash|akash-bittensor|akash-odysseus|akash-backend|terraform|azure|frontend|status)
      run bash scripts/deploy-production.sh "$TARGET"
      ;;
    *) die "unknown target: $TARGET" ;;
  esac
}

log "YieldSwarm deploy-all target=${TARGET} dry_run=${DRY_RUN}"
deploy_target
log "deploy-all complete"

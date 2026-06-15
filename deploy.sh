#!/usr/bin/env bash
# =============================================================================
# YieldSwarm AgentSwarm OS — FINAL PRODUCTION DEPLOYMENT ORCHESTRATOR
# =============================================================================
# Runs the full production deployment, in order:
#
#   1. Build & push Docker images to GHCR
#   2. Create the Akash lease  (+ start auto-heal)
#   3. Apply Terraform multi-cloud fallback
#   4. Update the frontend with real worker URLs
#   5. Start all monitoring + sovereign loops
#
# Usage:
#   ./deploy.sh                 # run all steps in order
#   ./deploy.sh --from 3        # resume from step 3
#   ./deploy.sh --only 1        # run only step 1
#   ./deploy.sh --dry-run       # print what each step would do
#   ./deploy.sh --help
#
# Config: copy deploy/config.env.example -> deploy/config.env and fill it in.
# Equivalent Makefile targets exist (see `make help`).
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/deploy/scripts/lib.sh"

FROM_STEP=1
ONLY_STEP=""
export DRY_RUN="${DRY_RUN:-0}"

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)    FROM_STEP="$2"; shift 2 ;;
    --only)    ONLY_STEP="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; export DRY_RUN; shift ;;
    -h|--help) usage 0 ;;
    *)         err "unknown arg: $1"; usage 1 ;;
  esac
done

load_config

should_run() {
  local n="$1"
  if [[ -n "$ONLY_STEP" ]]; then [[ "$n" == "$ONLY_STEP" ]]; return; fi
  (( n >= FROM_STEP ))
}

banner() {
  cat <<'EOF'

  ┌────────────────────────────────────────────────────────────┐
  │   YieldSwarm AgentSwarm OS — Production Deployment           │
  │   10,080 agents · 120 crons · Akash + multi-cloud fallback  │
  └────────────────────────────────────────────────────────────┘
EOF
  log "Image tag:    ${IMAGE_TAG}"
  log "GHCR owner:   ${GHCR_OWNER:-<unset>}"
  log "Akash SDL:    ${AKASH_SDL}"
  log "Dry run:      ${DRY_RUN}"
}

step1() { step "STEP 1/5 — Build & push images to GHCR"; bash "${REPO_ROOT}/deploy/scripts/build-and-push.sh"; }
step2() {
  step "STEP 2/5 — Akash lease creation + auto-heal setup"
  bash "${REPO_ROOT}/deploy/akash/create-lease.sh"
  bash "${REPO_ROOT}/deploy/akash/auto-heal.sh" --daemon
}
step3() { step "STEP 3/5 — Terraform multi-cloud fallback";    bash "${REPO_ROOT}/deploy/scripts/apply-terraform.sh" apply; }
step4() { step "STEP 4/5 — Update frontend with worker URLs";  bash "${REPO_ROOT}/deploy/scripts/update-frontend-urls.sh"; }
step5() {
  step "STEP 5/5 — Start monitoring + sovereign loops"
  bash "${REPO_ROOT}/deploy/scripts/start-monitoring.sh" up
  bash "${REPO_ROOT}/deploy/scripts/start-sovereign-loops.sh" start
}

run_step() {
  if [[ "$DRY_RUN" == "1" ]]; then
    warn "[dry-run] would run step $1"
    return 0
  fi
  "step$1"
}

main() {
  banner
  local t0; t0="$(date +%s)"
  for n in 1 2 3 4 5; do
    if should_run "$n"; then run_step "$n"; else log "skipping step $n"; fi
  done
  local dt=$(( $(date +%s) - t0 ))
  step "Deployment complete in ${dt}s"
  ok "Dashboard config: ${FRONTEND_CONFIG_OUT}"
  ok "Monitoring:       http://localhost:${PROMETHEUS_PORT} (Prometheus) / http://localhost:${GRAFANA_PORT} (Grafana)"
  ok "Loop status:      deploy/scripts/start-sovereign-loops.sh status"
  cat <<EOF

  YieldSwarm is LIVE. Sovereign loops running. Akash auto-heal active.
  Next: verify workers in the dashboard and Grafana, then point your
  domain/Vercel frontend at the worker URLs in ${FRONTEND_CONFIG_OUT}.
EOF
}

main "$@"

#!/usr/bin/env bash
# Production deployment from clean main — all 5 steps in order.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log() { echo "[deploy-all] $*"; }
fail() { echo "[deploy-all] ERROR: $*" >&2; exit 1; }

[[ "$(git branch --show-current)" == "main" ]] || log "WARN: not on main (current: $(git branch --show-current))"

log "Step 0: preflight"
make preflight || fail "preflight failed"

log "Step 1: Vault bootstrap (skip if already done)"
if [[ -n "${VAULT_TOKEN:-}" ]]; then
  ./vault/scripts/bootstrap.sh
  log "Seed secrets interactively: ./vault/scripts/seed-secrets.sh"
fi

log "Step 2: build & push images"
make build || fail "build failed"

log "Step 3: Akash lease"
export AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm}"
export AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"
./scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml || fail "akash deploy failed"

log "Step 4: Odysseus deploy"
./scripts/deploy-production-odysseus.sh || log "WARN: odysseus deploy skipped"

log "Step 5: multi-cloud fallback"
make terraform-apply || log "WARN: terraform apply skipped"

log "Step 6: frontend + monitoring"
make frontend monitoring-up sovereign-up || fail "frontend/monitoring failed"

log "Step 7: smoke tests"
./scripts/smoke-test.sh || fail "smoke tests failed"

log "Deploy complete. Run: make status"

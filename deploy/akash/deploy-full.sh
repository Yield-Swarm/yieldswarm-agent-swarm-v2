#!/usr/bin/env bash
# Full Vault-backed Akash deploy: preflight → monolith SDL → verify
#
# Usage:
#   export VAULT_ADDR=https://vault.yieldswarm.io:8200
#   export VAULT_TOKEN=<admin-or-bootstrap-token>   # never commit
#   export AKASH_KEY_NAME=yieldswarm
#   export AGENT_SHARD_ID=0
#   ./deploy/akash/deploy-full.sh
#
# Optional:
#   AKASH_PROVIDER=akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc  # europlots
#   AKASH_SDL=deploy/deploy-swarm-monolith.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

: "${VAULT_ADDR:?Set VAULT_ADDR (e.g. https://vault.yieldswarm.io:8200)}"

SDL="${AKASH_SDL:-deploy/deploy-swarm-monolith.yaml}"
PROVIDER="${AKASH_PROVIDER:-akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc}"

log() { printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

log "Preflight (must print GO)"
bash scripts/akash-preflight.sh "${SDL}"

log "Deploy monolith SDL → ${PROVIDER}"
export AKASH_PROVIDER="${PROVIDER}"
export VAULT_INJECT_RUNTIME_SECRETS="${VAULT_INJECT_RUNTIME_SECRETS:-yes}"
export AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"
bash scripts/deploy-to-akash.sh deploy "${SDL}"

log "Verify lease"
bash scripts/akash-verify-setup.sh 2>/dev/null || bash scripts/verify-akash-lease.sh || true

if [[ -f .run/akash-lease.env ]]; then
  log "Lease env written: .run/akash-lease.env"
  # shellcheck disable=SC1091
  source .run/akash-lease.env
  log "Worker URLs: ${AKASH_WORKER_URLS:-<set after manifest>}"
fi

log "Deploy-full complete"

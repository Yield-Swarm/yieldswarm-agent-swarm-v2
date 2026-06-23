#!/usr/bin/env bash
# Launch Poseidon Delta Trident v3.05911111100 on all infra + domains.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log() { printf '[trident-launch] %s\n' "$*" >&2; }

# Load secrets: Vault → trident env → .env
if [[ -n "${VAULT_ADDR:-}" && -n "${VAULT_TOKEN:-}" ]] && command -v vault >/dev/null 2>&1; then
  log "Loading Vault secrets (domains + trident runtime)..."
  export UD_API_KEY
  UD_API_KEY="$(vault kv get -field=api_key yieldswarm/integrations/unstoppable 2>/dev/null || vault kv get -field=UD_API_KEY yieldswarm/domains/runtime 2>/dev/null || true)"
  export VERCEL_TOKEN HELIOM_EDGE_INGEST_KEY
  VERCEL_TOKEN="$(vault kv get -field=VERCEL_TOKEN yieldswarm/domains/runtime 2>/dev/null || true)"
  HELIOM_EDGE_INGEST_KEY="$(vault kv get -field=HELIOM_EDGE_INGEST_KEY yieldswarm/runtime/trident 2>/dev/null || true)"
fi

[[ -f deploy/env/trident-mainnet.env ]] && set -a && source deploy/env/trident-mainnet.env && set +a
[[ -f .env ]] && set -a && source .env && set +a

export NODE_ENV="${NODE_ENV:-mainnet}"
export TRIDENT_VERSION="${TRIDENT_VERSION:-3.05911111100}"
export SYSTEM_CLOCK_TICK_RATE="${SYSTEM_CLOCK_TICK_RATE:-5000}"
export HELIX_CHAIN_ENABLED=1

ARGS=()
[[ "$DRY_RUN" == "1" ]] && ARGS+=(--dry-run)

log "Trident v${TRIDENT_VERSION} — wiring domains + chain + sovereign loops"
npx tsx scripts/mainnet-deploy.ts "${ARGS[@]}"

log "Verify:"
log "  curl -s http://127.0.0.1:${PORT:-8080}/api/helix/status | jq"
log "  cat .run/trident-mainnet-deploy.json"

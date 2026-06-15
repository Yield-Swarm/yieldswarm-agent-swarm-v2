#!/usr/bin/env bash
# Production deployment: Vault secrets → Akash monolith + Odysseus stack
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/vault-env.sh
. "${ROOT_DIR}/scripts/lib/vault-env.sh"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [vault-akash-deploy] $*"; }
fail() { log "ERROR: $*"; exit 1; }

usage() {
  cat <<'EOF'
Usage: scripts/deploy-vault-production.sh [--dry-run] [--odysseus-only] [--akash-only]

Vault-first production deploy for YieldSwarm:
  1. Load deploy secrets from HashiCorp Vault
  2. Bootstrap Vault AppRole wrap tokens for Akash (if AKASH_KEY_NAME set)
  3. Deploy Odysseus full stack (ChromaDB + LiteLLM + Odysseus) OR Akash monolith
  4. Start auto-healing loop

Environment:
  VAULT_ADDR                    Required
  VAULT_TOKEN or AppRole/JWT    Required
  YIELDSWARM_DEPLOY_VAULT_PATH  Default: kv/data/yieldswarm/deploy
  AKASH_KEY_NAME                Akash wallet key (optional for local compose)
  AKASH_DRY_RUN                 Set true to render SDL without creating lease
EOF
}

DRY_RUN=false
ODYSSEUS_ONLY=false
AKASH_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --odysseus-only) ODYSSEUS_ONLY=true ;;
    --akash-only) AKASH_ONLY=true ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $arg" ;;
  esac
done

DEPLOY_PATH="${YIELDSWARM_DEPLOY_VAULT_PATH:-kv/data/yieldswarm/deploy}"

log "Loading deployment secrets from Vault path: ${DEPLOY_PATH}"
vault_export_env "${DEPLOY_PATH}"

# Runtime paths for Odysseus
export ODYSSEUS_RUNTIME_VAULT_PATH="${ODYSSEUS_RUNTIME_VAULT_PATH:-kv/data/yieldswarm/odysseus/runtime}"
export ODYSSEUS_DEPLOY_VAULT_PATH="${ODYSSEUS_DEPLOY_VAULT_PATH:-kv/data/yieldswarm/odysseus/deploy}"

deploy_odysseus_stack() {
  log "Starting Odysseus full stack (ChromaDB + LiteLLM + Odysseus)"
  if [ "$DRY_RUN" = true ]; then
    log "DRY_RUN: would run docker compose -f docker-compose.odysseus-full.yml up -d"
    return 0
  fi
  docker compose -f "${ROOT_DIR}/docker-compose.odysseus-full.yml" up -d --build
  log "Odysseus health:"
  sleep 5
  curl -fsS "http://localhost:${ODYSSEUS_PORT:-7000}/healthz" || log "Odysseus not ready yet"
  curl -fsS "http://localhost:${ODYSSEUS_PORT:-7000}/api/swarm/status" | head -c 500 || true
  echo
}

deploy_akash_monolith() {
  log "Deploying Akash monolith with Vault runtime injection"
  if [ -z "${AKASH_KEY_NAME:-}" ]; then
    log "AKASH_KEY_NAME not set — skipping Akash lease (compose-only mode)"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log "DRY_RUN: would run scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml"
    return 0
  fi

  # Mint response-wrapped SecretID for Akash runtime (10 min TTL)
  if command -v vault >/dev/null 2>&1 && [ -n "${VAULT_ADDR:-}" ]; then
    export VAULT_WRAPPED_SECRET_ID
    VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=600s -force -format=json \
      auth/approle/role/akash-runtime/secret-id 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["wrap_info"]["token"])' || true)"
    export VAULT_ROLE_ID
    VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id 2>/dev/null || true)"
    log "Vault AppRole wrap minted for Akash runtime"
  fi

  export AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"
  "${ROOT_DIR}/scripts/akash-deploy.sh" "${ROOT_DIR}/deploy/deploy-swarm-monolith.yaml"

  log "Starting Akash auto-heal daemon"
  "${ROOT_DIR}/deploy/akash/auto-heal.sh" --daemon || true
}

if [ "$AKASH_ONLY" = false ]; then
  deploy_odysseus_stack
fi

if [ "$ODYSSEUS_ONLY" = false ]; then
  deploy_akash_monolith
fi

log "Production Vault + Akash deploy complete"
log "Next: make monitoring-up && make frontend"

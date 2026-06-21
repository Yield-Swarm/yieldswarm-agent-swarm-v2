#!/usr/bin/env bash
# Production mining deployment — auth + fleet connect + wallet routing + start
#
# Loads Vault secrets (~88 keys via seed-secrets.sh paths), connects Azure/Akash/local
# miners to funded wallets, and starts the unified mining manager.
#
# Usage:
#   export VAULT_ADDR VAULT_TOKEN   # or AppRole via akash-vault-prepare
#   export AGENTSWARM_MASTER_KEY=...  # mining auth signing
#   ./scripts/deploy-mining-production.sh
#
# Options:
#   MINING_DRY_RUN=1     config only, no process spawn
#   MINING_AUTH_SKIP=1   dev only — skip HMAC token gate
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log() { printf '[mining-deploy] %s\n' "$*" >&2; }

# ---- 1. Load secrets from Vault into environment -------------------------
if [[ -n "${VAULT_ADDR:-}" ]]; then
  log "injecting Vault secrets (mining + bittensor + wallets + akash)..."
  export VAULT_SECRET_PATHS="mining/wallets,runtime/bittensor,runtime/wallets,runtime/core,runtime/akash,rpc/bittensor"
  if [[ -f scripts/vault-export-env.py ]]; then
    # shellcheck disable=SC1091
    eval "$(python3 scripts/vault-export-env.py mining 2>/dev/null || true)"
  fi
  if [[ -f /run/secrets/agent.env ]]; then
  # shellcheck disable=SC1091
    set -a && source /run/secrets/agent.env && set +a
    log "loaded /run/secrets/agent.env"
  fi
else
  log "WARN: VAULT_ADDR unset — using local .env only"
fi

# ---- 2. Validate auth --------------------------------------------------
if [[ -z "${AGENTSWARM_MASTER_KEY:-}" && "${MINING_AUTH_SKIP:-}" != "1" ]]; then
  log "ERROR: set AGENTSWARM_MASTER_KEY or MINING_AUTH_SKIP=1 (dev only)" >&2
  exit 1
fi

# ---- 3. Wallet routing preflight ---------------------------------------
log "reward wallets:"
python3 - <<'PY'
import json, os
coins = {
  "tao": os.getenv("MINING_ROOT_TAO") or os.getenv("TAO_WALLET_ADDRESS"),
  "sol": os.getenv("NEXUS_TREASURY_SOLANA") or os.getenv("TREASURY_ADDRESS"),
  "etc": os.getenv("MINING_ROOT_BASE_ETC"),
  "xmr": os.getenv("MONERO_WALLET_ADDRESS"),
}
print(json.dumps({k: v for k, v in coins.items() if v}, indent=2))
PY

# ---- 4. Deploy fleet ---------------------------------------------------
export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"
export MINING_DRY_RUN="${MINING_DRY_RUN:-0}"
export REPO_ROOT

log "running unified mining manager deploy..."
python3 -m mining deploy --json

log "done — status: GET /api/mining/status or ./scripts/mining/status.sh"

#!/usr/bin/env bash
# YieldSwarm AgentSwarm container entrypoint.
# Fetches all secrets from Vault at runtime — nothing is baked into the image.
set -euo pipefail

log() {
  echo "[entrypoint] $*" >&2
}

# ---------------------------------------------------------------------------
# 1. Validate Vault connectivity prerequisites
# ---------------------------------------------------------------------------
if [[ -z "${VAULT_ADDR:-}" ]]; then
  log "FATAL: VAULT_ADDR not set. Secrets must be injected at runtime."
  exit 1
fi

if [[ -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ]]; then
  log "FATAL: VAULT_ROLE_ID and VAULT_SECRET_ID are required."
  log "       Generate a single-use secret-id: vault write -f auth/approle/role/akash-runtime/secret-id"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Fetch secrets from Vault
# ---------------------------------------------------------------------------
log "Fetching secrets from Vault at ${VAULT_ADDR}..."
/usr/local/bin/vault-fetch.sh

# Normalize Vault KV key names to application env conventions
export SOLANA_RPC_URL="${SOLANA_RPC_URL:-${PRIMARY_URL:-}}"
export FAILOVER_RPC_LIST="${FAILOVER_RPC_LIST:-${ENDPOINTS:-[]}}"

# ---------------------------------------------------------------------------
# 3. Validate critical secrets are present (never log values)
# ---------------------------------------------------------------------------
REQUIRED_KEYS=(
  "AGENTSWARM_MASTER_KEY"
  "SOLANA_RPC_URL"
)

for key in "${REQUIRED_KEYS[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    log "FATAL: Required secret ${key} not found after Vault fetch."
    exit 1
  fi
done

log "All required secrets present."

# ---------------------------------------------------------------------------
# 4. Start agent process
# ---------------------------------------------------------------------------
AGENT_MODULE="${AGENT_MODULE:-agents.akash_optimizer}"
SHARD_ID="${AGENT_SHARD_ID:-0}"

log "Starting agent module=${AGENT_MODULE} shard=${SHARD_ID}"
exec python -m "${AGENT_MODULE}" "$@"

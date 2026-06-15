#!/bin/sh
# =============================================================================
# entrypoint-inner.sh — Inner entrypoint (launched by Vault Agent exec stanza)
# YieldSwarm AgentSwarm OS v2.0
#
# By the time this script runs, Vault Agent has already rendered all secrets
# into /vault/secrets/agent.env. This script sources that file and starts
# the Python agent swarm.
#
# Vault Agent supervises this process; if the secrets file is updated
# (e.g. a key is rotated), Vault Agent sends SIGHUP and can restart this
# script to pick up new values.
# =============================================================================
set -eu

SECRETS_FILE="/vault/secrets/agent.env"

# ---------------------------------------------------------------------------
# Validate rendered secrets file
# ---------------------------------------------------------------------------
if [ ! -f "${SECRETS_FILE}" ]; then
  echo "[inner] FATAL: ${SECRETS_FILE} was not rendered by Vault Agent." >&2
  exit 1
fi

if [ ! -s "${SECRETS_FILE}" ]; then
  echo "[inner] FATAL: ${SECRETS_FILE} is empty — Vault Agent may have failed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Source secrets into environment
# ---------------------------------------------------------------------------
# shellcheck disable=SC1090
. "${SECRETS_FILE}"

# ---------------------------------------------------------------------------
# Record PID for graceful reload on secret rotation
# ---------------------------------------------------------------------------
echo $$ > /app/main.pid

# ---------------------------------------------------------------------------
# Verify a minimal set of critical secrets loaded before handing off
# ---------------------------------------------------------------------------
for required_var in SOLANA_RPC_URL AGENTSWARM_MASTER_KEY OPENAI_API_KEY; do
  eval "val=\${${required_var}:-}"
  if [ -z "${val}" ]; then
    echo "[inner] FATAL: Required secret ${required_var} is empty after sourcing ${SECRETS_FILE}." >&2
    exit 1
  fi
done

echo "[inner] Secrets loaded. Starting AgentSwarm OS..."

# ---------------------------------------------------------------------------
# Start the application
# ---------------------------------------------------------------------------
exec python3 /app/agents/akash-optimizer.py

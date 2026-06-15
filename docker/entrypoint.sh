#!/bin/sh
# =============================================================================
# entrypoint.sh — Outer entrypoint (PID 1)
# YieldSwarm AgentSwarm OS v2.0
#
# Responsibilities:
#   1. Validate required bootstrap env vars are present.
#   2. Write VAULT_ROLE_ID and VAULT_SECRET_ID to files consumed by Vault Agent.
#   3. Patch vault-agent.hcl with the actual VAULT_ADDR.
#   4. Start Vault Agent (which renders secrets and then execs entrypoint-inner.sh).
#
# Environment variables expected at container start:
#   VAULT_ADDR        (required) — https://vault.yieldswarm.internal:8200
#   VAULT_ROLE_ID     (required) — AppRole role_id
#   VAULT_SECRET_ID   (required) — AppRole secret_id (single-use, rotated per deploy)
#   VAULT_CACERT      (optional) — path to CA cert (or set VAULT_SKIP_VERIFY=true for dev)
#   VAULT_ENVIRONMENT (optional) — production | staging | dev (default: production)
#
# NEVER log VAULT_SECRET_ID or any resolved secret.
# =============================================================================
set -eu

# ---------------------------------------------------------------------------
# 1. Validate bootstrap env vars
# ---------------------------------------------------------------------------
if [ -z "${VAULT_ADDR:-}" ]; then
  echo "[entrypoint] FATAL: VAULT_ADDR is not set." >&2
  exit 1
fi
if [ -z "${VAULT_ROLE_ID:-}" ]; then
  echo "[entrypoint] FATAL: VAULT_ROLE_ID is not set." >&2
  exit 1
fi
if [ -z "${VAULT_SECRET_ID:-}" ]; then
  echo "[entrypoint] FATAL: VAULT_SECRET_ID is not set." >&2
  exit 1
fi

export VAULT_ENVIRONMENT="${VAULT_ENVIRONMENT:-production}"

echo "[entrypoint] Vault address: ${VAULT_ADDR}"
echo "[entrypoint] Environment:   ${VAULT_ENVIRONMENT}"

# ---------------------------------------------------------------------------
# 2. Write AppRole credentials to the filesystem (Vault Agent reads these)
#    Files are mode 0640; only the agentswarm user can read them.
# ---------------------------------------------------------------------------
printf '%s' "${VAULT_ROLE_ID}"   > /vault/auth/role-id
printf '%s' "${VAULT_SECRET_ID}" > /vault/auth/secret-id
chmod 640 /vault/auth/role-id /vault/auth/secret-id

# Unset env vars so they are not visible in /proc/<pid>/environ after writing
unset VAULT_ROLE_ID
unset VAULT_SECRET_ID

# ---------------------------------------------------------------------------
# 3. Patch vault-agent.hcl — substitute the placeholder with the real address
#    (Vault Agent does not support env var interpolation in address field)
# ---------------------------------------------------------------------------
sed "s|address = \"VAULT_ADDR\"|address = \"${VAULT_ADDR}\"|g" \
    /vault/config/agent.hcl > /vault/config/agent-runtime.hcl
chmod 640 /vault/config/agent-runtime.hcl

# ---------------------------------------------------------------------------
# 4. Start Vault Agent — it is now PID 1's child; exec replaces this shell
#    Vault Agent renders /vault/secrets/agent.env then execs entrypoint-inner.sh
# ---------------------------------------------------------------------------
echo "[entrypoint] Starting Vault Agent..."
exec vault agent -config=/vault/config/agent-runtime.hcl

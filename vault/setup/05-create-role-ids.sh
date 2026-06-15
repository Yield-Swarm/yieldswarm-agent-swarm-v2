#!/usr/bin/env bash
# =============================================================================
# 05-create-role-ids.sh — Generate Role IDs and Secret IDs for each AppRole
# YieldSwarm AgentSwarm OS v2.0
#
# Role IDs are stable identifiers (like usernames); store them in your CI/CD
# platform as non-secret env vars.
#
# Secret IDs are like passwords; store them as CI/CD secrets. For Akash
# deployments, generate a FRESH Secret ID per deployment (num_uses=1).
#
# Output: role-ids.env — sources ROLE_ID variables (safe to commit to CI env)
#         secret-ids.env — contains Secret IDs (NEVER COMMIT; delete after use)
#
# Prerequisites:
#   - VAULT_ADDR and VAULT_TOKEN exported
#   - AppRole roles created (04-configure-auth.sh)
# =============================================================================
set -euo pipefail

ROLES=("terraform" "akash-agents" "runpod" "vultr" "digitalocean")

ROLE_IDS_FILE="role-ids.env"
SECRET_IDS_FILE="secret-ids.env"

echo "# Role IDs — safe to store as non-secret CI env vars" > "${ROLE_IDS_FILE}"
echo "# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${ROLE_IDS_FILE}"
echo "" >> "${ROLE_IDS_FILE}"

echo "# Secret IDs — SENSITIVE — store in secrets manager, delete this file" > "${SECRET_IDS_FILE}"
echo "# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${SECRET_IDS_FILE}"
echo "# NEVER COMMIT THIS FILE. Run: shred -u ${SECRET_IDS_FILE}" >> "${SECRET_IDS_FILE}"
echo "" >> "${SECRET_IDS_FILE}"

for role in "${ROLES[@]}"; do
  ROLE_NAME_UPPER=$(echo "${role}" | tr '[:lower:]-' '[:upper:]_')

  # Role ID (stable, non-secret)
  ROLE_ID=$(vault read -field=role_id "auth/approle/role/${role}/role-id")
  echo "VAULT_ROLE_ID_${ROLE_NAME_UPPER}=${ROLE_ID}" >> "${ROLE_IDS_FILE}"
  echo "[05] ${role} role_id: ${ROLE_ID}"

  # Secret ID (rotatable, sensitive)
  SECRET_ID=$(vault write -field=secret_id -f "auth/approle/role/${role}/secret-id")
  echo "VAULT_SECRET_ID_${ROLE_NAME_UPPER}=${SECRET_ID}" >> "${SECRET_IDS_FILE}"
  echo "[05] ${role} secret_id: [generated — see ${SECRET_IDS_FILE}]"
  echo ""
done

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  NEXT STEPS                                                     ║"
echo "║                                                                  ║"
echo "║  1. Upload role-ids.env to your CI platform (GitHub Actions,    ║"
echo "║     Akash deploy scripts, etc.) as non-secret env vars.         ║"
echo "║                                                                  ║"
echo "║  2. Upload secret-ids.env values to your CI platform as         ║"
echo "║     ENCRYPTED SECRETS (GitHub Actions > Secrets, etc.).         ║"
echo "║                                                                  ║"
echo "║  3. For each Akash deploy, generate a FRESH secret_id:          ║"
echo "║     vault write -field=secret_id -f \\                           ║"
echo "║       auth/approle/role/akash-agents/secret-id                  ║"
echo "║                                                                  ║"
echo "║  4. Delete secret-ids.env now:                                   ║"
echo "║     shred -u ${SECRET_IDS_FILE}                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

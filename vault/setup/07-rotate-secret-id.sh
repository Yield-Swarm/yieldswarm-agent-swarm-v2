#!/usr/bin/env bash
# =============================================================================
# 07-rotate-secret-id.sh — Generate a fresh Secret ID for a deployment
# YieldSwarm AgentSwarm OS v2.0
#
# Call this script immediately before each Akash/RunPod/Vultr/DO deployment
# to get a single-use Secret ID. The resulting value is injected into the
# container's VAULT_SECRET_ID environment variable.
#
# Usage:
#   ./07-rotate-secret-id.sh <role-name>
#   ./07-rotate-secret-id.sh akash-agents
#
# Output: prints the one-time Secret ID to stdout (pipe to CI env or clipboard)
# =============================================================================
set -euo pipefail

ROLE="${1:?Usage: $0 <role-name> (e.g. akash-agents)}"

NEW_SECRET_ID=$(vault write -field=secret_id -f "auth/approle/role/${ROLE}/secret-id")

echo "${NEW_SECRET_ID}"

#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh
# -----------------------------------------------------------------------------
# Orchestrator: runs every 0X / 1X / 2X / 3X bootstrap step in order. Each
# step is idempotent on its own and safe to re-run individually for
# troubleshooting.
#
# Usage:
#     export VAULT_ADDR=https://vault.yieldswarm.internal:8200
#     export VAULT_TOKEN=hvs.xxxxxxxxxxxxxxxxxxxxxxxx     # admin / root
#     ./bootstrap.sh
#
# Output: a tab-separated table of AppRole role_ids and wrapped secret_ids.
# Wrapped tokens have a 5-minute TTL; deliver them through your secure
# channel (Bitwarden Send, Vault Cubbyhole, etc.) and unwrap from the target
# host within the window.
# =============================================================================
set -Eeuo pipefail
shopt -s inherit_errexit

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI not found in PATH" >&2; exit 127
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found in PATH" >&2; exit 127
fi

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

bold "=== 00 enable engines ==="
"${HERE}/00-enable-engines.sh"

bold "=== 10 install policies ==="
"${HERE}/10-policies.sh"

bold "=== 20 provision approles ==="
APPROLE_OUT="$("${HERE}/20-approles.sh")"

bold "=== 30 seed placeholder secrets ==="
"${HERE}/30-seed-secrets.sh"

bold "=== AppRole credentials (DELIVER VIA SECURE CHANNEL) ==="
printf '%s\n' "$APPROLE_OUT"

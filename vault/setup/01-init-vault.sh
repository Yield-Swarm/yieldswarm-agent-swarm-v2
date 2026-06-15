#!/usr/bin/env bash
# =============================================================================
# 01-init-vault.sh — Initialize Vault and save recovery keys
# YieldSwarm AgentSwarm OS v2.0
#
# Run once on a fresh Vault cluster. Never re-run on an initialized cluster.
#
# Prerequisites:
#   - VAULT_ADDR exported (e.g. export VAULT_ADDR=https://vault.yieldswarm.internal:8200)
#   - VAULT_CACERT exported if using a private CA
#   - vault CLI installed (https://developer.hashicorp.com/vault/downloads)
#
# Output:
#   - vault-init.json  — ENCRYPTED recovery keys + root token (store in
#                        Azure Key Vault or an offline HSM, never in git)
# =============================================================================
set -euo pipefail

VAULT_INIT_FILE="vault-init.json"
KEY_SHARES=5
KEY_THRESHOLD=3

echo "[01] Checking Vault status..."
STATUS=$(vault status -format=json 2>/dev/null || true)
INITIALIZED=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('initialized','false'))" 2>/dev/null || echo "false")

if [ "$INITIALIZED" = "True" ] || [ "$INITIALIZED" = "true" ]; then
  echo "[01] Vault is already initialized. Skipping."
  exit 0
fi

echo "[01] Initializing Vault with ${KEY_SHARES} key shares, threshold ${KEY_THRESHOLD}..."
vault operator init \
  -key-shares="${KEY_SHARES}" \
  -key-threshold="${KEY_THRESHOLD}" \
  -format=json > "${VAULT_INIT_FILE}"

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  CRITICAL: vault-init.json has been written to disk.            ║"
echo "║  It contains unseal keys and the root token.                    ║"
echo "║                                                                  ║"
echo "║  1. Immediately upload it to Azure Key Vault:                   ║"
echo "║     az keyvault secret set \\                                     ║"
echo "║       --vault-name <your-kv> \\                                   ║"
echo "║       --name vault-init-recovery \\                               ║"
echo "║       --file vault-init.json                                    ║"
echo "║                                                                  ║"
echo "║  2. Then DELETE the local copy:                                  ║"
echo "║     shred -u vault-init.json                                    ║"
echo "║                                                                  ║"
echo "║  3. Distribute unseal key shards to ${KEY_THRESHOLD}/${KEY_SHARES} separate     ║"
echo "║     custodians via encrypted channels.                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Extract and display the root token for immediate use
ROOT_TOKEN=$(python3 -c "import json; d=json.load(open('${VAULT_INIT_FILE}')); print(d['root_token'])")
echo "[01] Root token: ${ROOT_TOKEN}"
echo "[01] Export it now: export VAULT_TOKEN=${ROOT_TOKEN}"
echo ""
echo "[01] Vault initialized. Proceed to 02-enable-engines.sh"

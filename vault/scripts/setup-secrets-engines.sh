#!/usr/bin/env bash
# Enable KV v2 secrets engine and configure the yieldswarm secret namespace.
# Requires: VAULT_ADDR, VAULT_TOKEN (root or admin token during bootstrap)
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR (e.g. https://vault.yieldswarm.internal:8200)}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN for bootstrap}"

echo "==> Enabling KV v2 secrets engine at secret/"
if ! vault secrets list -format=json | jq -e '.["secret/"]' >/dev/null 2>&1; then
  vault secrets enable -path=secret kv-v2
else
  echo "    secret/ already enabled"
fi

echo "==> Configuring KV v2 max versions and deletion protection"
vault write secret/config max_versions=10 delete_version_after="720h"

echo "==> Creating yieldswarm secret path structure (placeholder metadata only)"
# Placeholder writes establish paths; replace values before production use.
declare -a PATHS=(
  "yieldswarm/azure/credentials"
  "yieldswarm/runpod/api"
  "yieldswarm/vultr/api"
  "yieldswarm/digitalocean/api"
  "yieldswarm/rpc/solana"
  "yieldswarm/rpc/failover"
  "yieldswarm/akash/runtime"
  "yieldswarm/akash/deploy"
  "yieldswarm/agents/shared"
)

for p in "${PATHS[@]}"; do
  if vault kv get -mount=secret "$p" >/dev/null 2>&1; then
    echo "    secret/$p already exists — skipping"
  else
    vault kv put "secret/$p" _placeholder="replace-me" _note="Bootstrap placeholder — see SECRETS.md"
    echo "    Created secret/$p (placeholder)"
  fi
done

echo "==> Secrets engines configured."

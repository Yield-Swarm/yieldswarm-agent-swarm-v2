#!/usr/bin/env bash
# Seed secret paths with placeholder structure.
# Replace values via: vault kv put yieldswarm/azure key=value ...
# NEVER run with real secrets in CI logs.
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

MOUNT="yieldswarm"

put_if_missing() {
  local path="$1"
  shift
  if vault kv get -mount="${MOUNT}" "${path}" >/dev/null 2>&1; then
    echo "SKIP ${path} (already exists)"
  else
    vault kv put -mount="${MOUNT}" "${path}" "$@"
    echo "CREATED ${path}"
  fi
}

put_if_missing "azure" \
  subscription_id="REPLACE_ME" \
  client_id="REPLACE_ME" \
  client_secret="REPLACE_ME" \
  tenant_id="REPLACE_ME" \
  resource_group="yieldswarm-prod" \
  location="eastus"

put_if_missing "runpod" \
  api_key="REPLACE_ME" \
  endpoint="https://api.runpod.io/graphql"

put_if_missing "vultr" \
  api_key="REPLACE_ME"

put_if_missing "digitalocean" \
  token="REPLACE_ME" \
  spaces_access_key="REPLACE_ME" \
  spaces_secret_key="REPLACE_ME" \
  spaces_region="nyc3"

put_if_missing "rpc" \
  solana_rpc_url="https://api.mainnet-beta.solana.com" \
  helius_api_key="REPLACE_ME" \
  failover_rpc_list='["https://rpc1.example.com","https://rpc2.example.com"]' \
  birdeye_api_key="REPLACE_ME" \
  jupiter_api_key="REPLACE_ME"

put_if_missing "agents/runtime" \
  agentswarm_master_key="REPLACE_ME" \
  kimiclaw_consensus_key="REPLACE_ME" \
  grok_api_key="REPLACE_ME" \
  openai_api_key="REPLACE_ME" \
  gemini_api_key="REPLACE_ME" \
  anthropic_api_key="REPLACE_ME" \
  wallet_encryption_key="REPLACE_ME" \
  tee_signing_key="REPLACE_ME" \
  database_encryption_key="REPLACE_ME" \
  gpu_cluster_keys='["REPLACE_ME"]' \
  agent_shard_id="0" \
  agent_count_total="10080" \
  agents_per_shard="84"

echo "Secret paths seeded. Replace REPLACE_ME values before production use."

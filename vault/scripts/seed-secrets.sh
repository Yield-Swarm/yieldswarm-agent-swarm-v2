#!/usr/bin/env bash
# Seed production secret values into Vault.
# Run interactively or export env vars before executing.
# NEVER commit real values — this script reads from your shell environment.
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN}"

echo "==> Seeding Azure credentials"
vault kv put secret/yieldswarm/azure/credentials \
  client_id="${AZURE_CLIENT_ID:?Set AZURE_CLIENT_ID}" \
  client_secret="${AZURE_CLIENT_SECRET:?Set AZURE_CLIENT_SECRET}" \
  subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID}" \
  tenant_id="${AZURE_TENANT_ID:?Set AZURE_TENANT_ID}"

echo "==> Seeding RunPod API key"
vault kv put secret/yieldswarm/runpod/api \
  api_key="${RUNPOD_API_KEY:?Set RUNPOD_API_KEY}"

echo "==> Seeding Vultr API key"
vault kv put secret/yieldswarm/vultr/api \
  api_key="${VULTR_API_KEY:?Set VULTR_API_KEY}"

echo "==> Seeding DigitalOcean API token"
vault kv put secret/yieldswarm/digitalocean/api \
  api_token="${DO_API_TOKEN:?Set DO_API_TOKEN}"

echo "==> Seeding RPC endpoints"
vault kv put secret/yieldswarm/rpc/solana \
  primary_url="${SOLANA_RPC_URL:?Set SOLANA_RPC_URL}" \
  helius_api_key="${HELIUS_API_KEY:-}" \
  birdeye_api_key="${BIRDEYE_API_KEY:-}"

vault kv put secret/yieldswarm/rpc/failover \
  endpoints="${FAILOVER_RPC_LIST:?Set FAILOVER_RPC_LIST as JSON array string}"

echo "==> Seeding Akash runtime secrets"
vault kv put secret/yieldswarm/akash/runtime \
  wallet_mnemonic="${AKASH_WALLET_MNEMONIC:?Set AKASH_WALLET_MNEMONIC}" \
  keyring_backend="${AKASH_KEYRING_BACKEND:-test}" \
  chain_id="${AKASH_CHAIN_ID:-akashnet-2}" \
  node="${AKASH_NODE:-https://rpc.akash.forbole.com:443}"

echo "==> Seeding Akash deploy secrets (SDL signing)"
vault kv put secret/yieldswarm/akash/deploy \
  certificate="${AKASH_CERTIFICATE:?Set AKASH_CERTIFICATE}" \
  key="${AKASH_KEY:?Set AKASH_KEY}"

echo "==> Seeding shared agent secrets"
vault kv put secret/yieldswarm/agents/shared \
  agentswarm_master_key="${AGENTSWARM_MASTER_KEY:?Set AGENTSWARM_MASTER_KEY}" \
  openai_api_key="${OPENAI_API_KEY:-}" \
  grok_api_key="${GROK_API_KEY:-}" \
  gpu_cluster_keys="${GPU_CLUSTER_KEYS:-[]}"

echo "==> All secrets seeded. Verify with: vault kv list secret/yieldswarm/"

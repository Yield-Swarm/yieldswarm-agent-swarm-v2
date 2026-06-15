#!/usr/bin/env bash
# =============================================================================
# 06-seed-secrets.sh — Write initial secrets to Vault KV v2
# YieldSwarm AgentSwarm OS v2.0
#
# HOW TO USE:
#   1. Copy this file: cp 06-seed-secrets.sh 06-seed-secrets.local.sh
#   2. Fill in real values in the LOCAL copy.
#   3. Run the LOCAL copy (never commit it — it's in .gitignore).
#   4. Verify: vault kv get secret/yieldswarm/production/infra/azure
#
# All vault kv put commands are idempotent; re-running creates a new version.
#
# Prerequisites:
#   - VAULT_ADDR and VAULT_TOKEN exported
#   - KV v2 engine enabled (02-enable-engines.sh)
#   - Set VAULT_ENVIRONMENT (default: production)
# =============================================================================
set -euo pipefail

ENV="${VAULT_ENVIRONMENT:-production}"

echo "[06] Seeding secrets for environment: ${ENV}"
echo "[06] Replace every CHANGEME value before running!"
echo ""

# =============================================================================
# INFRASTRUCTURE PROVIDERS
# =============================================================================

echo "[06] Writing Azure credentials..."
vault kv put "secret/yieldswarm/${ENV}/infra/azure" \
  client_id="CHANGEME_azure_client_id" \
  client_secret="CHANGEME_azure_client_secret" \
  tenant_id="CHANGEME_azure_tenant_id" \
  subscription_id="CHANGEME_azure_subscription_id"

echo "[06] Writing RunPod credentials..."
vault kv put "secret/yieldswarm/${ENV}/infra/runpod" \
  api_key="CHANGEME_runpod_api_key"

echo "[06] Writing Vultr credentials..."
vault kv put "secret/yieldswarm/${ENV}/infra/vultr" \
  api_key="CHANGEME_vultr_api_key"

echo "[06] Writing DigitalOcean credentials..."
vault kv put "secret/yieldswarm/${ENV}/infra/digitalocean" \
  api_token="CHANGEME_do_api_token"

# =============================================================================
# RPC ENDPOINTS
# =============================================================================

echo "[06] Writing Solana RPC endpoints..."
vault kv put "secret/yieldswarm/${ENV}/rpc/solana" \
  primary_url="https://api.mainnet-beta.solana.com" \
  helius_api_key="CHANGEME_helius_api_key" \
  birdeye_api_key="CHANGEME_birdeye_api_key" \
  jupiter_api_key="CHANGEME_jupiter_api_key" \
  raydium_api_key="CHANGEME_raydium_api_key" \
  dexscreener_api_key="CHANGEME_dexscreener_api_key" \
  solscan_api_key="CHANGEME_solscan_api_key" \
  failover_list='["https://rpc.helius.xyz?api-key=CHANGEME","https://solana-api.projectserum.com"]'

# =============================================================================
# BLOCKCHAIN / ON-CHAIN KEYS
# =============================================================================

echo "[06] Writing blockchain keys..."
vault kv put "secret/yieldswarm/${ENV}/blockchain/keys" \
  pump_fun_deploy_key="CHANGEME_pump_fun_deploy_key" \
  ton_api_key="CHANGEME_ton_api_key" \
  tao_subnet_key="CHANGEME_tao_subnet_key" \
  helix_bridge_key="CHANGEME_helix_bridge_key" \
  zec_shielded_key="CHANGEME_zec_shielded_key" \
  erc4337_bundler_key="CHANGEME_erc4337_bundler_key" \
  bittensor_staking_key="CHANGEME_bittensor_staking_key"

# =============================================================================
# CORE AGENT SECRETS
# =============================================================================

echo "[06] Writing core agent secrets..."
vault kv put "secret/yieldswarm/${ENV}/agents/core" \
  master_key="CHANGEME_agentswarm_master_key" \
  kimiclaw_consensus_key="CHANGEME_kimiclaw_consensus_key" \
  wallet_encryption_key="CHANGEME_wallet_encryption_key" \
  tee_signing_key="CHANGEME_tee_signing_key" \
  database_encryption_key="CHANGEME_database_encryption_key"

# =============================================================================
# LLM / AI PROVIDERS
# =============================================================================

echo "[06] Writing LLM provider keys..."
vault kv put "secret/yieldswarm/${ENV}/llm/providers" \
  grok_api_key="CHANGEME_grok_api_key" \
  openai_api_key="CHANGEME_openai_api_key" \
  gemini_api_key="CHANGEME_gemini_api_key" \
  anthropic_api_key="CHANGEME_anthropic_api_key" \
  arena_key="CHANGEME_quarantined_llm_arena_key"

# =============================================================================
# DEPIN HARDWARE
# =============================================================================

echo "[06] Writing DePIN hardware keys..."
vault kv put "secret/yieldswarm/${ENV}/depin/hardware" \
  helium_hotspot_keys='["CHANGEME_hotspot1","CHANGEME_hotspot2"]' \
  gpu_cluster_keys='["CHANGEME_runpod_key1","CHANGEME_rtx4090_key"]' \
  grass_node_keys='["CHANGEME_grass_node1"]' \
  smartthings_bridge_token="CHANGEME_smartthings_token" \
  utility_api_key="CHANGEME_utility_api_key"

# =============================================================================
# INTEGRATIONS
# =============================================================================

echo "[06] Writing productivity integration keys..."
vault kv put "secret/yieldswarm/${ENV}/integrations/productivity" \
  notion_api_key="CHANGEME_notion_api_key" \
  linear_api_key="CHANGEME_linear_api_key" \
  vercel_api_token="CHANGEME_vercel_api_token" \
  github_token="CHANGEME_github_token" \
  sp_api_key="CHANGEME_sp_api_key" \
  fsd_data_feed_key="CHANGEME_fsd_data_feed_key" \
  tesla_integration_token="CHANGEME_tesla_integration_token"

echo "[06] Writing social integration keys..."
vault kv put "secret/yieldswarm/${ENV}/integrations/social" \
  telegram_bot_token="CHANGEME_telegram_bot_token" \
  x_api_keys='["CHANGEME_x_key1","CHANGEME_x_key2"]' \
  meta_ads_token="CHANGEME_meta_ads_token"

echo "[06] Writing payment keys..."
vault kv put "secret/yieldswarm/${ENV}/integrations/payments" \
  ud_api_key="CHANGEME_ud_api_key" \
  filecoin_storage_key="CHANGEME_filecoin_storage_key"

# =============================================================================
# MONITORING
# =============================================================================

echo "[06] Writing monitoring config..."
vault kv put "secret/yieldswarm/${ENV}/monitoring/config" \
  prometheus_url="CHANGEME_prometheus_url" \
  error_webhook="CHANGEME_error_webhook_url" \
  zkml_verifier_key="CHANGEME_zkml_verifier_key"

echo ""
echo "[06] All secrets written for environment: ${ENV}"
echo "[06] Verify a secret: vault kv get secret/yieldswarm/${ENV}/infra/azure"
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  SECURITY REMINDER: Delete this local copy now.                 ║"
echo "║  shred -u 06-seed-secrets.local.sh                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

#!/usr/bin/env bash
# vault/scripts/seed-secrets.sh
#
# One-shot seeding of the KV v2 paths consumed by Terraform and the Akash runtime.
# Reads values from environment variables (NEVER pass them as CLI args — that
# leaks into shell history and process listings).
#
# Usage:
#   export VAULT_ADDR=... VAULT_TOKEN=...   # admin token
#   export AZURE_CLIENT_ID=... AZURE_CLIENT_SECRET=... AZURE_TENANT_ID=... AZURE_SUBSCRIPTION_ID=...
#   export RUNPOD_API_KEY=...
#   export VULTR_API_KEY=...
#   export DIGITALOCEAN_TOKEN=...
#   export SOLANA_RPC_URL=... HELIUS_API_KEY=... BIRDEYE_API_KEY=... JUPITER_API_KEY=...
#   export AGENTSWARM_MASTER_KEY=... OPENAI_API_KEY=... ANTHROPIC_API_KEY=... GROK_API_KEY=...
#   export WALLET_ENCRYPTION_KEY=... TEE_SIGNING_KEY=...
#   ./vault/scripts/seed-secrets.sh
#
# Re-runnable: kv put is upsert; existing values are overwritten only for
# variables that are actually set in the environment.

set -Eeuo pipefail
: "${VAULT_ADDR:?}"
: "${VAULT_TOKEN:?}"
KV_MOUNT="${KV_MOUNT:-yieldswarm}"

log() { printf '[seed] %s\n' "$*" >&2; }

put_if_set() {
  # put_if_set <kv-path> <vault-key>=<envvar> [...]
  local path="$1"; shift
  local -a kvargs=()
  local pair k v val any=0
  for pair in "$@"; do
    k="${pair%%=*}"
    v="${pair#*=}"
    val="${!v:-}"
    if [[ -n "${val}" ]]; then
      kvargs+=( "${k}=${val}" )
      any=1
    fi
  done
  if (( any == 0 )); then
    log "skip ${path} (no env vars set)"
    return 0
  fi
  log "writing ${KV_MOUNT}/${path} (${#kvargs[@]} keys)"
  vault kv put "${KV_MOUNT}/${path}" "${kvargs[@]}" >/dev/null
}

# ---- Cloud providers (consumed by terraform/) ----
put_if_set providers/azure \
  client_id=AZURE_CLIENT_ID \
  client_secret=AZURE_CLIENT_SECRET \
  tenant_id=AZURE_TENANT_ID \
  subscription_id=AZURE_SUBSCRIPTION_ID

put_if_set providers/runpod \
  api_key=RUNPOD_API_KEY

put_if_set providers/vultr \
  api_key=VULTR_API_KEY

put_if_set providers/digitalocean \
  token=DIGITALOCEAN_TOKEN \
  spaces_access_id=DIGITALOCEAN_SPACES_ACCESS_ID \
  spaces_secret_key=DIGITALOCEAN_SPACES_SECRET_KEY

# ---- RPC endpoints (consumed by both terraform/ and the Akash runtime) ----
put_if_set rpc/solana \
  url=SOLANA_RPC_URL \
  helius_api_key=HELIUS_API_KEY \
  birdeye_api_key=BIRDEYE_API_KEY \
  jupiter_api_key=JUPITER_API_KEY

put_if_set rpc/ethereum \
  url=ETHEREUM_RPC_URL \
  alchemy_api_key=ALCHEMY_API_KEY \
  infura_project_id=INFURA_PROJECT_ID \
  infura_api_key=INFURA_API_KEY

put_if_set rpc/infura \
  project_id=INFURA_PROJECT_ID \
  api_key=INFURA_API_KEY \
  sol_mainnet_rpc=INFURA_SOL_MAINNET_RPC

put_if_set rpc/ankr \
  api_key=ANKR_API_KEY \
  multichain_rpc=ANKR_RPC_MULTICHAIN

put_if_set integrations/quicknode \
  api_key=QUICKNODE_API_KEY \
  rpc_url=QUICKNODE_RPC_URL

put_if_set integrations/tenderly \
  api_key=TENDERLY_API_KEY \
  account=TENDERLY_ACCOUNT \
  project=TENDERLY_PROJECT

put_if_set integrations/sentry \
  dsn=SENTRY_DSN \
  environment=SENTRY_ENVIRONMENT \
  traces_sample_rate=SENTRY_TRACES_SAMPLE_RATE

put_if_set integrations/cloudflare \
  api_token=CLOUDFLARE_API_TOKEN \
  client_id=CLOUDFLARE_CLIENT_ID \
  client_secret=CLOUDFLARE_CLIENT_SECRET \
  zone_id=CLOUDFLARE_ZONE_ID

put_if_set integrations/pinata \
  api_key=PINATA_API_KEY \
  secret=PINATA_SECRET \
  jwt=PINATA_JWT

put_if_set integrations/livepeer \
  api_key=LIVEPEER_API_KEY

put_if_set rpc/ton \
  api_key=TON_API_KEY

put_if_set rpc/bittensor \
  staking_key=NG64_BITTENSOR_NODE_STAKING_KEY

# ---- Runtime secrets (consumed only by the Akash workload via vault-agent) ----
put_if_set runtime/core \
  agentswarm_master_key=AGENTSWARM_MASTER_KEY \
  kimiclaw_consensus_key=KIMICLAW_CONSENSUS_KEY \
  database_encryption_key=DATABASE_ENCRYPTION_KEY

put_if_set runtime/llm \
  openai_api_key=OPENAI_API_KEY \
  anthropic_api_key=ANTHROPIC_API_KEY \
  grok_api_key=GROK_API_KEY \
  gemini_api_key=GEMINI_API_KEY \
  openrouter_api_key=OPENROUTER_API_KEY \
  fireworks_api_key=FIREWORKS_API_KEY

put_if_set runtime/wallets \
  wallet_encryption_key=WALLET_ENCRYPTION_KEY \
  tee_signing_key=TEE_SIGNING_KEY \
  pump_fun_deploy_key=PUMP_FUN_DEPLOY_KEY \
  erc4337_bundler_key=ERC4337_BUNDLER_KEY \
  helix_chain_bridge_key=HELIX_CHAIN_BRIDGE_KEY \
  zec_shielded_key=ZEC_SHIELDED_KEY

put_if_set integrations/github  token=GITHUB_TOKEN
put_if_set integrations/vercel  token=VERCEL_API_TOKEN
put_if_set integrations/notion  api_key=NOTION_API_KEY
put_if_set integrations/linear  api_key=LINEAR_API_KEY
put_if_set integrations/telegram bot_token=TELEGRAM_BOT_TOKEN
put_if_set integrations/unstoppable api_key=UD_API_KEY

# ---- Kairo (driver app) ----
put_if_set runtime/kairo \
  mapbox_token=MAPBOX_TOKEN \
  iotex_api_key=IOTEX_API_KEY \
  identity_signing_key=KAIRO_IDENTITY_SIGNING_KEY

# ---- Payments (Stripe, Square, Wise) ----
put_if_set runtime/payments \
  stripe_secret_key=STRIPE_SECRET_KEY \
  stripe_webhook_secret=STRIPE_WEBHOOK_SECRET \
  stripe_publishable_key=STRIPE_PUBLISHABLE_KEY \
  square_access_token=SQUARE_ACCESS_TOKEN \
  square_webhook_secret=SQUARE_WEBHOOK_SECRET \
  wise_api_token=WISE_API_TOKEN

put_if_set integrations/stripe \
  secret_key=STRIPE_SECRET_KEY \
  webhook_secret=STRIPE_WEBHOOK_SECRET \
  publishable_key=STRIPE_PUBLISHABLE_KEY

put_if_set integrations/mapbox \
  token=MAPBOX_TOKEN

# ---- ZK entropy (pillar 03) ----
put_if_set runtime/zk \
  verifier_address=ZK__VERIFIER_ADDRESS \
  mutation_controller=MUTATION_CONTROLLER_ADDRESS \
  nft_address=YIELDSWARM_NFT_ADDRESS \
  circuit_wasm_path=ZK__CIRCUIT_WASM_PATH \
  zkey_path=ZK__ZKEY_PATH \
  vkey_path=ZK__VKEY_PATH

# ---- Odysseus orchestration ----
put_if_set runtime/odysseus \
  api_key=ODYSSEUS_API_KEY \
  model_host=ODYSSEUS_MODEL_HOST \
  model_api_key=ODYSSEUS_MODEL_API_KEY \
  chromadb_host=CHROMADB_HOST \
  router_api_key=YIELDSWARM_ROUTER_API_KEY \
  openrouter_api_key=OPENROUTER_API_KEY \
  fireworks_api_key=FIREWORKS_API_KEY

# ---- Akash deploy metadata (integration backend + lease tracking) ----
put_if_set runtime/akash \
  owner_address=AKASH_OWNER_ADDRESS \
  key_name=AKASH_KEY_NAME \
  mnemonic=AKASH_WALLET_MNEMONIC

# ---- Integration backend (Arena API on Akash) ----
put_if_set runtime/backend \
  emission_router_address=EMISSION_ROUTER_ADDRESS \
  treasury_address=TREASURY_ADDRESS \
  apn_mint=APN_MINT_ADDRESS \
  odysseus_brain_url=ODYSSEUS_BRAIN_URL \
  split_core_bps=SPLIT_CORE_BPS \
  split_growth_bps=SPLIT_GROWTH_BPS \
  split_insurance_bps=SPLIT_INSURANCE_BPS \
  split_ops_bps=SPLIT_OPS_BPS

# ---- Bittensor miner (Akash dual-purpose worker) ----
put_if_set runtime/bittensor \
  wallet_name=BT_WALLET_NAME \
  hotkey_name=BT_HOTKEY_NAME \
  wallet_json=BITTENSOR_WALLET_JSON \
  netuid=BT_NETUID \
  network=BT_NETWORK \
  ollama_model=OLLAMA_MODEL

# ---- Tri-Solenoid runtime bundles (Nexus / Helix / Shadow) ---------------
put_if_set treasury/manifest \
  version=TREASURY_MANIFEST_VERSION \
  nexus_solana=NEXUS_TREASURY_SOLANA \
  manifest_json=TREASURY_MANIFEST_JSON

put_if_set treasury/mining_roots \
  base_etc=MINING_ROOT_BASE_ETC \
  zec=MINING_ROOT_ZEC \
  prl=MINING_ROOT_PRL \
  tao=MINING_ROOT_TAO \
  base_hype=MINING_ROOT_BASE_HYPE \
  base_cbeth=MINING_ROOT_BASE_CBETH \
  base_btc=MINING_ROOT_BASE_BTC \
  iotex=MINING_ROOT_IOTEX \
  btc_via_iopay=MINING_ROOT_BTC_IOPAY

put_if_set iotex/hub \
  primary=IOTEX_HUB_PRIMARY \
  btc_bridge=IOTEX_HUB_BTC_BRIDGE

put_if_set runtime/nexus \
  nexus_chain_url=NEXUS_CHAIN_URL \
  orchestrator_key=NEXUS_ORCHESTRATOR_KEY \
  max_agents=NEXUS_MAX_AGENTS

put_if_set runtime/helix \
  helix_chain_url=HELIX_CHAIN_URL \
  helix_program_id=HELIX_PROGRAM_ID \
  helix_chain_bridge_key=HELIX_CHAIN_BRIDGE_KEY

put_if_set runtime/shadow \
  shadow_chain_url=SHADOW_CHAIN_URL \
  arena_program_id=ARENA_PROGRAM_ID \
  swarm_ops_program_id=SWARM_OPS_PROGRAM_ID

# ---- Akash deploy operator config (deploy host, not container) ---------
put_if_set runtime/akash \
  key_name=AKASH_KEY_NAME \
  mnemonic=AKASH_WALLET_MNEMONIC \
  node=AKASH_NODE \
  chain_id=AKASH_CHAIN_ID

log "done"

# Environment Variables Catalog — YieldSwarm AgentSwarm OS v2.0

> As of June 2026 · **Names only** — never commit values.  
> **Layered template:** `deploy/env/layered.env.example`  
> **Deploy order:** `docs/DEPLOYMENT_PRIORITY.md`  
> **Vault injection:** `docs/VAULT_ENV_INJECTION.md`  
> Template: `.env.example` · Vault seed: `vault/scripts/seed-secrets.sh`  
> Council add-ons: `docs/COUNCIL_WISHLIST.md`

---

## 0. Quadrilateral axis layers (Phase 1)

| Prefix | Axis | Purpose |
|--------|------|---------|
| `GREEK_LAYER__*` | D¹ | Access control, sanitization, context caps |
| `EASTERN_LAYER__*` | E¹ | Feedback loops, recursive routing |
| `ZK__*` | Z¹ | Circuit paths, verifier, mutation contracts |
| `LLM__*` | Router | Odysseus + LiteLLM default model/type |
| `DEFAULT_LOCALE`, `SUPPORTED_LOCALES` | W | Rosetta i18n |

Full layered file: `deploy/env/layered.env.example`.

---

## 1. Vault & deployment

| Variable | Purpose |
|----------|---------|
| `VAULT_ADDR` | HashiCorp Vault server URL |
| `VAULT_NAMESPACE` | Enterprise namespace (optional) |
| `VAULT_TOKEN` | Operator/admin token (deploy host only — never in SDL/git) |
| `VAULT_AUTH_METHOD` | `jwt`, `approle`, or `token` |
| `VAULT_JWT_AUTH_PATH` | JWT login path |
| `VAULT_JWT_ROLE` | JWT role name |
| `VAULT_JWT_FILE` | Service account JWT file (Akash) |
| `VAULT_TOKEN_FILE` | Token file path |
| `VAULT_ROLE_ID` | AppRole role_id (non-sensitive; injected via `--env` at Akash deploy) |
| `VAULT_WRAPPED_SECRET_ID` | One-shot response-wrap token (Akash bootstrap) |
| `VAULT_SECRET_ID_WRAP_TOKEN` | Alias for wrapped SecretID (`issue-secret-id.sh`) |
| `VAULT_AKASH_ROLE` | AppRole to mint: `akash-runtime` or `bittensor-runtime` |
| `VAULT_WRAP_TTL` | Wrap TTL at deploy time (default `600s`) |
| `VAULT_INJECT_RUNTIME_SECRETS` | `auto` / `yes` / `no` — deploy script injection |
| `USE_VAULT_AKASH` | Route `deploy.sh` step 2 through Vault SDL deploy |
| `VAULT_LOAD_AKASH` | Load Akash wallet config from Vault on deploy host |
| `VAULT_AKASH_SECRET_PATH` | KV path for deploy-host Akash config |
| `AGENT_SHARD_ID` | Shard index `0..119` for per-shard KV |
| `AGENT_ENV_FILE` | Vault Agent render target (default `/run/secrets/agent.env`) |
| `ODYSSEUS_RUNTIME_VAULT_PATH` | KV path for Odysseus runtime |
| `ODYSSEUS_DEPLOY_VAULT_PATH` | KV path for deploy-only secrets |

**Akash runtime injection:** see `docs/VAULT_AKASH_RUNTIME.md`.

---

## 2. Core auth & security

| Variable | Purpose |
|----------|---------|
| `AGENTSWARM_MASTER_KEY` | Master swarm encryption key |
| `KIMICLAW_CONSENSUS_KEY` | Kimiclaw council signing |
| `GROK_API_KEY` | xAI Grok API |
| `OPENAI_API_KEY` | OpenAI API |
| `GEMINI_API_KEY` | Google Gemini API |
| `ANTHROPIC_API_KEY` | Anthropic API |
| `OPENROUTER_API_KEY` | OpenRouter multi-model API |
| `FIREWORKS_API_KEY` | Fireworks AI API |
| `WALLET_ENCRYPTION_KEY` | Wallet data encryption |
| `TEE_SIGNING_KEY` | TEE signing key |
| `DATABASE_ENCRYPTION_KEY` | DB encryption key |
| `SESSION_SECRET` | Next.js session signing |

---

## 3. Odysseus + LLM router

| Variable | Purpose |
|----------|---------|
| `APP_BIND`, `APP_PORT` | Odysseus workspace bind |
| `ODYSSEUS_ADMIN_USER`, `ODYSSEUS_ADMIN_PASSWORD` | Workspace admin |
| `LLM_ROUTER_BIND`, `LLM_ROUTER_PORT` | LiteLLM router |
| `YIELDSWARM_ROUTER_API_KEY` | Router auth key |
| `LITELLM_URL` | LiteLLM base URL (brain) |
| `ODYSSEUS_DEFAULT_MODEL` | Primary model alias (`akash-ollama`) |
| `AKASH_OLLAMA_BASE_URL`, `AKASH_OLLAMA_HOSTS` | RTX 3090 Ollama endpoints |
| `AKASH_OLLAMA_MODEL`, `AKASH_OLLAMA_EMBED_MODEL` | Ollama model names |
| `LOCAL_OLLAMA_BASE_URL`, `LOCAL_OLLAMA_MODEL` | Local fallback |
| `ODYSSEUS_BRAIN_URL` | Central brain API |
| `ODYSSEUS_ROUTER_SYNC_SECONDS` | Model routing sync interval |
| `YIELDSWARM_SYNC_AKASH_WORKERS` | Auto-sync workers from lease URLs |
| `AKASH_WORKER_URLS` | Comma-separated live worker URLs |
| `YIELDSWARM_AKASH_WORKERS` | JSON worker fleet definition |
| `YIELDSWARM_RTX3090_WORKER_COUNT` | Default simulated worker count |
| `YIELDSWARM_MODEL_CATALOG` | JSON model VRAM catalog |
| `YIELDSWARM_ROUTER_HOST`, `YIELDSWARM_ROUTER_PORT` | Standalone routing API |

---

## 4. Blockchain & RPC

| Variable | Purpose |
|----------|---------|
| `SOLANA_RPC_URL` | Solana JSON-RPC |
| `HELIUS_API_KEY` | Helius enhanced RPC |
| `BIRDEYE_API_KEY` | Birdeye market data |
| `JUPITER_API_KEY` | Jupiter swap API |
| `RAYDIUM_API_KEY` | Raydium API |
| `PUMP_FUN_DEPLOY_KEY` | Pump.fun deploy |
| `TON_API_KEY` | TON API |
| `TAO_SUBNET_KEY` | Bittensor subnet |
| `HELIX_CHAIN_BRIDGE_KEY` | Helix bridge signing key (Vault → Akash runtime) |
| `HELIX_CHAIN_ENABLED` | Set `1` after `./scripts/activate-helix.sh` |
| `YIELDSWARM_HELIX_EMISSION_ROUTER` | Helix emission router address for agent tools |
| `HELIX_CONTROL_PLANE_URL` | Great Delta / Helix ingest control plane |
| `YIELDSWARM_EMISSION_ROUTER_URL` | Backend URL for `yieldswarm_emission_router_query` tool |
| `NEXUS_TREASURY_SOLANA` | Primary Nexus Treasury (Solana) |
| `MINING_ROOT_BASE_ETC` | ETC mining root address |
| `MINING_ROOT_ZEC` | Zcash mining root |
| `MINING_ROOT_PRL` | PRL mining root (Solana) |
| `MINING_ROOT_TAO` | Bittensor mining root |
| `MINING_ROOT_BASE_HYPE` | Base HYPE mining root |
| `MINING_ROOT_BASE_CBETH` | Base cbETH mining root |
| `MINING_ROOT_BASE_BTC` | Base BTC mining root |
| `IOTEX_TREASURY` | IoTeX hub primary treasury (Helix Solenoid 2) |
| `IOTEX_BTC_BRIDGE` | BTC via IOPAY bridge address |
| `TREASURY_MANIFEST_PATH` | Override path to `TREASURY_MANIFEST.json` |
| `NODE5_ENABLED` | Enable Node 5 PyHackathon Stellar + Cosmos module |
| `NODE5_DRY_RUN` | Dry-run Node 5 chain ops (default `1`) |
| `STELLAR_SECRET_KEY` | Stellar signer secret (Vault / SecretProd.pdf) |
| `STELLAR_PUBLIC_KEY` | Stellar account public key |
| `STELLAR_DESTINATION_ADDRESS` | Stellar treasury / payout address |
| `STELLAR_NETWORK` | `public` or `testnet` |
| `STELLAR_HORIZON_URL` | Horizon API base URL |
| `COSMOS_MNEMONIC` | Cosmos wallet mnemonic (live txs) |
| `COSMOS_ADDRESS` | Cosmos bech32 address |
| `COSMOS_CHAIN_ID` | e.g. `akashnet-2` |
| `COSMOS_REST_URL` | Cosmos REST endpoint |
| `ZEC_SHIELDED_KEY` | Zcash shielded |
| `ERC4337_BUNDLER_KEY` | Account abstraction bundler |
| `INFURA_PROJECT_ID`, `INFURA_API_KEY`, `INFURA_SOL_MAINNET_RPC` | Infura RPC |
| `ANKR_API_KEY`, `ANKR_RPC_MULTICHAIN` | Ankr multichain RPC |
| `QUICKNODE_API_KEY`, `QUICKNODE_RPC_URL` | QuickNode RPC |
| `ETHEREUM_RPC_URL` | Ethereum RPC |
| `ALCHEMY_API_KEY` | Alchemy RPC |
| `FAILOVER_RPC_LIST` | JSON RPC fallback list |

---

## 5. $APN token

| Variable | Purpose |
|----------|---------|
| `APN_MINT_ADDRESS` | Solana mint (public) |
| `PUMP_FUN_COIN_ID` | Pump.fun coin ID |
| `RAYDIUM_POOL_ID`, `LP_TOKEN_ADDRESS` | Pool addresses |
| `SLIPPAGE_TOLERANCE`, `MAX_FEE_PERCENT` | Trading params |
| `EMISSION_ROUTER_ADDRESS`, `TREASURY_ADDRESS` | On-chain addresses |
| `SPLIT_CORE_BPS`, `SPLIT_GROWTH_BPS`, `SPLIT_INSURANCE_BPS`, `SPLIT_OPS_BPS` | 50/30/15/5 split |

---

## 6. Agents, crons, DePIN

| Variable | Purpose |
|----------|---------|
| `AGENT_COUNT_TOTAL` | 10,080 agents |
| `AGENTS_PER_SHARD`, `AGENT_SHARD_ID` | Shard sizing |
| `CRON_SHARD_COUNT`, `CRON_INTERVAL_MINUTES` | Cron config |
| `DEPIN_HELIUM_HOTSPOT_KEYS` | Helium hotspots JSON (serial, MAC, SSID, wallet) |
| `GPU_CLUSTER_KEYS` | GPU cluster keys JSON |
| `GRASS_NODE_KEYS` | Grass DePIN node keys / wallets JSON |
| `GRASS_LINEUPS` | Grass device lineups with platform multipliers |
| `MINING_DRY_RUN` | Dry-run mining manager (default `1`) |
| `MINING_AUTO_START` | Auto-start miners on sovereign tick |
| `MINING_ROOT_TAO` | Bittensor coldkey / payout address |
| `MONERO_WALLET_ADDRESS` | Monero (XMR) payout address |
| `MINING_ROOT_BASE_ETC` | Ethereum Classic payout address |
| `MONERO_POOL_URL`, `ETC_POOL_URL` | Pool endpoints |
| `XMRIG_PATH`, `ETC_MINER_BINARY` | Miner binary paths |
| `SMARTTHINGS_BRIDGE_TOKEN` | SmartThings |
| `COLORADO_POWER_PERMIT_ID`, `UTILITY_API_KEY` | Energy permits |

---

## 7. ChromaDB / Odysseus memory

| Variable | Purpose |
|----------|---------|
| `ODYSSEUS_CHROMA_MODE` | `http`, `persistent`, `jsonl` |
| `ODYSSEUS_CHROMA_HOST`, `ODYSSEUS_CHROMA_PORT` | ChromaDB endpoint |
| `ODYSSEUS_CHROMA_TOKEN` | Chroma auth |
| `ODYSSEUS_SYNC_PEERS`, `ODYSSEUS_SYNC_TOKEN` | Peer gossip sync |
| `ODYSSEUS_CHROMA_URL` | Kairo → Odysseus forward URL |

---

## 8. Payments (Square, Wise, Stripe, Web3)

| Variable | Purpose |
|----------|---------|
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` | Stripe rails |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Stripe client |
| `SQUARE_ACCESS_TOKEN`, `SQUARE_LOCATION_ID` | Square deposits |
| `SQUARE_WEBHOOK_SIGNATURE_KEY` | Square webhooks |
| `WISE_API_TOKEN`, `WISE_PROFILE_ID` | Wise transfers |
| `TREASURY_EVM_ADDRESS`, `TREASURY_SOLANA_ADDRESS`, `TREASURY_TON_ADDRESS` | Treasury wallets |
| `HOT_WALLET_EVM_PRIVATE_KEY`, `HOT_WALLET_SOLANA_SECRET_KEY` | Hot wallets (Vault only) |
| `EVM_RPC_URL_*` | Per-chain RPC for Web3 |

---

## 9. Kairo driver app

| Variable | Purpose |
|----------|---------|
| `KAIRO_API_PORT`, `KAIRO_API_URL` | Driver API |
| `KAIRO_IDENTITY_STORE`, `KAIRO_MANDELBROT_STORE` | Local data paths |
| `KAIRO_DEPIN_REWARD_RATE` | DePIN reward rate |
| `VITE_MAPBOX_TOKEN`, `VITE_KAIRO_API_URL` | Frontend |

---

## 10. Integrations

| Variable | Purpose |
|----------|---------|
| `NOTION_API_KEY`, `LINEAR_API_KEY` | Productivity |
| `VERCEL_API_TOKEN`, `GITHUB_TOKEN` | Deploy / CI |
| `UD_API_KEY` | Unstoppable Domains |
| `WISE_BUSINESS_EMAIL` | Wise business account |
| `TELEGRAM_BOT_TOKEN`, `X_API_KEYS` | Social |
| `META_ADS_TOKEN`, `AD_CAMPAIGN_BUDGET` | Marketing |

---

## 11. Monitoring & optional

| Variable | Purpose |
|----------|---------|
| `LOG_LEVEL` | Logging verbosity |
| `MONITORING_PROMETHEUS_URL` | Prometheus |
| `ERROR_WEBHOOK` | Alert webhook |
| `NETWORK_LOCKDOWN_MODE` | Security lockdown |
| `BUG_BOUNTY_AGENT_ENABLED` | Immunefi agent |
| `DEXSCREENER_API`, `SOLSCAN_API_KEY` | On-chain analytics |

---

## 12. Council Wishlist (8 services)

| Variable | Service |
|----------|---------|
| `QUICKNODE_API_KEY`, `QUICKNODE_RPC_URL` | QuickNode |
| `TENDERLY_API_KEY`, `TENDERLY_ACCOUNT`, `TENDERLY_PROJECT` | Tenderly |
| `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE` | Sentry |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_CLIENT_ID`, `CLOUDFLARE_CLIENT_SECRET`, `CLOUDFLARE_ZONE_ID` | Cloudflare |
| `PINATA_API_KEY`, `PINATA_SECRET`, `PINATA_JWT` | Pinata IPFS |
| `LIVEPEER_API_KEY` | Livepeer video |

See `docs/COUNCIL_WISHLIST.md` for enable steps.

---

## 13. Platform deploy (Vercel / Render / Akash / Azure)

| Variable | Platform | Purpose |
|----------|----------|---------|
| `GHCR_OWNER`, `GHCR_TOKEN`, `IMAGE_TAG` | All containers | Image registry |
| `AKASH_KEY_NAME`, `AKASH_SDL`, `AKASH_NODE` | Akash | Lease creation |
| `BT_NETUID`, `BT_NETWORK` | Akash Bittensor | Subnet targeting |
| `BACKEND_IMAGE`, `ODYSSEUS_IMAGE` | Akash SDL | Container image refs |
| `VERCEL_DEPLOY_HOOK` | Vercel | Post-deploy frontend trigger |
| `KAIRO_API_BASE`, `MAPBOX_TOKEN` | Vercel | Frontend env (dashboard aliases) |
| `RENDER_API_KEY`, `RENDER_SERVICE_ID` | Render | Fallback API redeploy |
| `TF_ENABLE_RENDER`, `TF_ENABLE_FLY`, `TF_ENABLE_HETZNER` | Terraform fallback | Toggle providers |
| `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` | Azure SP | Via Vault `providers/azure` |
| `AZURE_SSH_PUBLIC_KEY`, `AZURE_ADMIN_USERNAME` | Azure VM SSH | Vault `providers/azure` · `scripts/azure/wire-ssh-key.sh` |
| `DEPLOY_SSH_PUBLIC_KEY` | Multicloud VM SSH | Shared Vultr/DO/Azure |
| `TFC_ORGANIZATION`, `TFC_WORKSPACE` | Terraform Cloud | Remote state (`Helixchainprod`) |

---

## How to load secrets safely

```bash
# 1. Fill a local .env (gitignored) — use placeholders from .env.example
cp .env.example .env

# 2. Seed Vault (never commit .env)
export VAULT_ADDR=... VAULT_TOKEN=...
set -a && source .env && set +a
./vault/scripts/seed-secrets.sh

# 3. Runtime injection (Akash / deploy)
source scripts/lib/vault-env.sh
vault_export_env kv/data/yieldswarm/runtime/llm
```

**Total tracked variables:** ~180 across all sections above.  
**Spin-up runbook:** `PRODUCTION_SPINUP.md`

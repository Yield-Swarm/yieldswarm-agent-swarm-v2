# ENV_VARS.md — YieldSwarm Environment Variable Catalog

> **As of:** 2026-06-13 (updated 2026-06-15)  
> **Template:** copy `.env.example` → `.env` and fill values locally.  
> **Production:** store secrets in HashiCorp Vault (`yieldswarm/` KV mount). Never commit real values.

---

## Security rules

1. `.env` is gitignored — use it only on trusted local/deploy hosts.
2. Vercel/Azure/Akash: inject via Vault Agent or platform secret stores.
3. Rotate any key that has appeared in chat, tickets, or commit history.
4. Council Wishlist keys below are **optional** until the integration is wired.

---

## Quick reference by subsystem

| Subsystem | Primary vars | Vault path |
|-----------|--------------|------------|
| Vault bootstrap | `VAULT_ADDR`, `VAULT_TOKEN` | — |
| Core auth | `AGENTSWARM_MASTER_KEY`, `SESSION_SECRET` | `runtime/core`, `runtime/payments` |
| LLM providers | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, … | `runtime/llm` |
| RPC / chain | `SOLANA_RPC_URL`, `HELIUS_API_KEY`, … | `rpc/*` |
| Odysseus | `ODYSSEUS_*`, `CHROMADB_*` | `runtime/odysseus` |
| Payments | `STRIPE_*`, `SQUARE_*`, `WISE_*` | `runtime/payments`, `integrations/stripe` |
| Kairo | `KAIRO_*`, `VITE_MAPBOX_TOKEN` | `runtime/kairo` |
| Akash deploy | `AKASH_KEY_NAME`, JWT scripts | `ODYSSEUS_DEPLOY_VAULT_PATH` |
| Domains | `UD_API_KEY` | `integrations/unstoppable` |
| Council Wishlist | `QUICKNODE_*`, `SENTRY_DSN`, … | `integrations/*` (when enabled) |

---

## 1. HashiCorp Vault

| Variable | Required | Description |
|----------|----------|-------------|
| `VAULT_ADDR` | prod | Vault API URL |
| `VAULT_NAMESPACE` | optional | Enterprise namespace |
| `VAULT_AUTH_METHOD` | prod | `jwt`, `approle`, or `token` |
| `VAULT_JWT_AUTH_PATH` | jwt | e.g. `auth/jwt/login` |
| `VAULT_JWT_ROLE` | jwt | e.g. `yieldswarm-odysseus-runtime` |
| `VAULT_JWT_FILE` | jwt | Service account token path |
| `VAULT_TOKEN_FILE` | optional | Short-lived token file |
| `ODYSSEUS_RUNTIME_VAULT_PATH` | odysseus | KV path for runtime secrets |
| `ODYSSEUS_DEPLOY_VAULT_PATH` | deploy | KV path for deploy-only secrets |

---

## 2. Critical — core auth & security

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENTSWARM_MASTER_KEY` | yes | Master encryption/signing root |
| `KIMICLAW_CONSENSUS_KEY` | yes | Kimiclaw council consensus |
| `GROK_API_KEY` | llm | xAI Grok API |
| `OPENAI_API_KEY` | llm | OpenAI |
| `GEMINI_API_KEY` | llm | Google Gemini |
| `OPENROUTER_API_KEY` | llm | OpenRouter multi-model |
| `ANTHROPIC_API_KEY` | llm | Anthropic Claude |
| `WALLET_ENCRYPTION_KEY` | yes | Wallet at-rest encryption |
| `TEE_SIGNING_KEY` | tee | TEE signing material |
| `DATABASE_ENCRYPTION_KEY` | yes | DB field encryption |
| `SESSION_SECRET` | payments | Next.js session HMAC (required in prod runtime) |

---

## 3. Odysseus workspace + LLM router

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_BIND` | `127.0.0.1` | Odysseus bind address |
| `APP_PORT` | `7000` | Odysseus HTTP port |
| `AUTH_ENABLED` | `true` | Require auth |
| `ODYSSEUS_ADMIN_USER` | — | Bootstrap admin username |
| `ODYSSEUS_ADMIN_PASSWORD` | — | Bootstrap admin password |
| `ODYSSEUS_BUILD_CONTEXT` | git URL | Odysseus image source |
| `ODYSSEUS_OLLAMA_BASE_URL` | local | Ollama OpenAI-compatible URL |
| `LLM_ROUTER_BIND` | `127.0.0.1` | LiteLLM bind |
| `LLM_ROUTER_PORT` | `4000` | LiteLLM port |
| `YIELDSWARM_ROUTER_API_KEY` | — | Router auth key |
| `OPENROUTER_MODEL` | — | Default OpenRouter model |
| `FIREWORKS_API_KEY` | optional | Fireworks AI |
| `AKASH_OLLAMA_*` | — | Akash-hosted Ollama workers |
| `LOCAL_OLLAMA_*` | — | Local dev Ollama |
| `ODYSSEUS_IMAGE` | ghcr | Container image tag |
| `YIELDSWARM_DEITY_COUNT` | `169` | Deity manifest count |
| `ODYSSEUS_BRAIN_URL` | `8090` | Central brain service URL |

### ChromaDB memory

| Variable | Description |
|----------|-------------|
| `ODYSSEUS_CHROMA_MODE` | `http`, `persistent`, or `jsonl` |
| `ODYSSEUS_CHROMA_HOST` | ChromaDB host |
| `ODYSSEUS_CHROMA_PORT` | ChromaDB port |
| `ODYSSEUS_CHROMA_TOKEN` | Auth token |
| `ODYSSEUS_CHROMA_*` | Tenant, database, sync peers |

---

## 4. Blockchain & RPC

| Variable | Description |
|----------|-------------|
| `SOLANA_RPC_URL` | Primary Solana HTTP RPC |
| `HELIUS_API_KEY` | Helius enhanced Solana API |
| `BIRDEYE_API_KEY` | Birdeye market data |
| `JUPITER_API_KEY` | Jupiter swap API |
| `RAYDIUM_API_KEY` | Raydium pools |
| `PUMP_FUN_DEPLOY_KEY` | Pump.fun deploy signer |
| `TON_API_KEY` | TON API |
| `TAO_SUBNET_KEY` | Bittensor subnet |
| `HELIX_CHAIN_BRIDGE_KEY` | Helix bridge |
| `ZEC_SHIELDED_KEY` | Zcash shielded ops |
| `ERC4337_BUNDLER_KEY` | Account-abstraction bundler |
| `INFURA_API_KEY` | Infura project ID (EVM) |
| `INFURA_PROJECT_ID` | Alias for Infura project ID |
| `INFURA_SOL_MAINNET_RPC` | Infura Solana mainnet URL |
| `ANKR_API_KEY` | Ankr multichain API key |
| `ANKR_RPC_MAINNET` | Ankr multichain RPC URL |
| `ETHEREUM_RPC_URL` | Primary EVM RPC (Terraform) |
| `ALCHEMY_API_KEY` | Alchemy (optional; QuickNode can replace) |
| `FAILOVER_RPC_LIST` | JSON array of backup RPC URLs |

---

## 5. $APN — Apollo Nexus Engine

| Variable | Description |
|----------|-------------|
| `APN_MINT_ADDRESS` | $APN mint (public on-chain) |
| `PUMP_FUN_COIN_ID` | Pump.fun coin id |
| `RAYDIUM_POOL_ID` | Raydium LP pool |
| `LP_TOKEN_ADDRESS` | LP token mint |
| `SLIPPAGE_TOLERANCE` | Default `0.005` |
| `MAX_FEE_PERCENT` | Platform fee cap (`0.01` = 1%) |
| `IMPERMANENT_LOSS_THRESHOLD` | IL guard threshold |
| `MAYHEM_MODE_ENABLED` | Feature flag |

---

## 6. Operations, DePIN, yield & cron

| Variable | Description |
|----------|-------------|
| `AGENT_COUNT_TOTAL` | `10080` |
| `AGENTS_PER_SHARD` | `84` |
| `AGENT_SHARD_ID` | `0`–`119` per cron |
| `CRON_SHARD_COUNT` | `120` |
| `CRON_INTERVAL_MINUTES` | Default `15` |
| `DEPIN_HELIUM_HOTSPOT_KEYS` | JSON array |
| `GPU_CLUSTER_KEYS` | JSON array |
| `GRASS_NODE_KEYS` | JSON array |
| `YIELDSWARM_RTX3090_WORKER_COUNT` | GPU worker count |
| `YIELDSWARM_AKASH_WORKERS` | JSON worker catalog |
| `YIELDSWARM_MODEL_CATALOG` | JSON model routing catalog |
| `YIELDSWARM_ROUTER_HOST` / `PORT` | Model router bind |
| `RATE_LIMIT_RPM` | API rate limit |
| `TOKEN_BUDGET_DAILY` | LLM token budget |
| `REFERRAL_BONUS_RATE` | Referral % |
| `AGENT_REFERRAL_TARGET` | Referral goal |

---

## 7. Integrations

| Variable | Vault path | Description |
|----------|------------|-------------|
| `NOTION_API_KEY` | `integrations/notion` | Notion workspace |
| `LINEAR_API_KEY` | `integrations/linear` | Linear issues |
| `VERCEL_API_TOKEN` | `integrations/vercel` | Vercel deploy API |
| `GITHUB_TOKEN` | `integrations/github` | GitHub API |
| `UD_API_KEY` | `integrations/unstoppable` | Unstoppable Domains |
| `TELEGRAM_BOT_TOKEN` | `integrations/telegram` | Telegram bot |
| `WISE_BUSINESS_EMAIL` | — | Wise business account email |

---

## 8. Payment rails (Next.js)

| Variable | Description |
|----------|-------------|
| `APP_URL` / `NEXT_PUBLIC_APP_URL` | Public app URL |
| `STRIPE_SECRET_KEY` | Stripe secret (server) |
| `STRIPE_WEBHOOK_SECRET` | Webhook signing secret |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Stripe publishable key |
| `NEXT_PUBLIC_PLATFORM_FEE_RATE` | `0.01` = 1% on top of credit |
| `SQUARE_*` | Square access token, location, webhooks |
| `WISE_*` | Wise API token, profile, webhook key |
| `TREASURY_EVM_ADDRESS` | On-chain deposit address |
| `TREASURY_SOLANA_ADDRESS` | Solana treasury |
| `TREASURY_TON_ADDRESS` | TON treasury |
| `HOT_WALLET_*` | Withdrawal hot wallets (high risk) |
| `SPLIT_*_BPS` | Great Delta 50/30/15/5 split |
| `EMISSION_ROUTER_ADDRESS` | On-chain router |

See `.env.example` § Payment Rails for the full Square/Wise/Web3 block.

---

## 9. Kairo driver app

| Variable | Description |
|----------|-------------|
| `KAIRO_API_PORT` | Default `8100` |
| `KAIRO_API_URL` | Kairo backend URL |
| `KAIRO_IDENTITY_STORE` | Identity persistence path |
| `KAIRO_DEPIN_REWARD_RATE` | DePIN reward rate |
| `KAIRO_CORS_ORIGINS` | Allowed CORS origins |
| `VITE_KAIRO_API_URL` | Frontend API URL |
| `VITE_MAPBOX_TOKEN` | Mapbox GL token |
| `MAPBOX_TOKEN` | Server-side Mapbox (Vercel env) |

---

## 10. Arena, telemetry & frontend

| Variable | Description |
|----------|-------------|
| `AKASH_TELEMETRY_URL` | `/api/telemetry/akash` |
| `ODYSSEUS_TELEMETRY_URL` | `/api/telemetry/odysseus` |
| `YIELDSWARM_TELEMETRY_REFRESH_MS` | Poll interval |
| `YIELDSWARM_AUTH_SESSION_URL` | Session endpoint |
| `YIELDSWARM_AUTH_HANDOFF_URL` | Odysseus handoff |
| `QUARANTINED_LLM_ARENA_KEY` | Arena sandbox key |

---

## 11. Monitoring & optional

| Variable | Description |
|----------|-------------|
| `LOG_LEVEL` | `INFO`, `DEBUG`, … |
| `ERROR_WEBHOOK` | Alert webhook URL |
| `MONITORING_PROMETHEUS_URL` | Prometheus scrape |
| `NETWORK_LOCKDOWN_MODE` | Restrict egress |
| `DEXSCREENER_API` | DexScreener |
| `SOLSCAN_API_KEY` | Solscan |
| `EMAIL_SMTP_CONFIG` | JSON SMTP config |
| `BACKUP_CRON_INTERVAL` | Minutes between backups |
| `BUG_BOUNTY_AGENT_ENABLED` | Immune bounty agent |
| `NG64_BITTENSOR_NODE_STAKING_KEY` | Bittensor staking |
| `META_ADS_TOKEN` | Meta ads |
| `X_API_KEYS` | JSON array of X API keys |

---

## 12. Council Wishlist — recommended additional services

Optional integrations to supercharge the agent swarm. Add to Vault when ready.

### QuickNode — multi-chain RPC

| Variable | Description |
|----------|-------------|
| `QUICKNODE_API_KEY` | QuickNode API key |
| `QUICKNODE_SOLANA_RPC` | Solana endpoint URL |
| `QUICKNODE_ETHEREUM_RPC` | Ethereum endpoint URL |

**Use case:** redundant RPC across 15+ chains; reduces Alchemy dependency.  
**Vault path:** `yieldswarm/rpc/quicknode`

### Tenderly — transaction simulation

| Variable | Description |
|----------|-------------|
| `TENDERLY_API_KEY` | Tenderly access key |
| `TENDERLY_ACCOUNT_SLUG` | Account slug |
| `TENDERLY_PROJECT_SLUG` | Project slug |

**Use case:** simulate Arena contract txs before mining; debug failures.  
**Vault path:** `yieldswarm/integrations/tenderly`

### Sentry — error tracking

| Variable | Description |
|----------|-------------|
| `SENTRY_DSN` | Project DSN (`https://…@us.sentry.io/…`) |
| `SENTRY_AUTH_TOKEN` | API token for releases |
| `SENTRY_ORG` | Organization slug |
| `SENTRY_PROJECT` | Project slug |
| `NEXT_PUBLIC_SENTRY_DSN` | Browser DSN (if using client SDK) |

**Use case:** production crash reporting, performance traces, source maps.  
**Vault path:** `yieldswarm/integrations/sentry`

### Cloudflare — CDN, R2, Workers, Access

| Variable | Description |
|----------|-------------|
| `CLOUDFLARE_API_TOKEN` | Global API token |
| `CLOUDFLARE_ACCOUNT_ID` | Account ID |
| `CLOUDFLARE_CLIENT_ID` | Access service token ID |
| `CLOUDFLARE_CLIENT_SECRET` | Access service token secret |
| `CLOUDFLARE_R2_ACCESS_KEY_ID` | R2 S3-compatible key |
| `CLOUDFLARE_R2_SECRET_ACCESS_KEY` | R2 secret |
| `CLOUDFLARE_R2_BUCKET` | R2 bucket name |

**Use case:** DDoS protection, CDN, R2 media storage, edge Workers.  
**Vault path:** `yieldswarm/integrations/cloudflare`

### Pinata — IPFS pinning

| Variable | Description |
|----------|-------------|
| `PINATA_API_KEY` | Pinata API key |
| `PINATA_SECRET` | Pinata API secret |
| `PINATA_JWT` | Pinata JWT (scoped uploads) |
| `IPFS_GATEWAY` | Public gateway (`https://ipfs.io` or Pinata dedicated) |

**Use case:** decentralized storage for agent artifacts, lore, report archives.  
**Vault path:** `yieldswarm/integrations/pinata`

### Livepeer — decentralized video

| Variable | Description |
|----------|-------------|
| `LIVEPEER_API_KEY` | Livepeer Studio API key |
| `LIVEPEER_WEBHOOK_SECRET` | Webhook signing secret |

**Use case:** community video, education streams, DePIN video content.  
**Vault path:** `yieldswarm/integrations/livepeer`  
**Note:** fork [livepeer/studio](https://github.com/livepeer/studio) or use Studio API when key is issued.

---

## 13. Seeding Vault from environment

```bash
export VAULT_ADDR=https://vault.yieldswarm.io
export VAULT_TOKEN=...   # admin, short-lived

# Export only the keys you are seeding (never commit this block)
export OPENAI_API_KEY=...
export STRIPE_SECRET_KEY=...
# ...

./vault/scripts/seed-secrets.sh
# or: vault/setup/bootstrap.sh (first-time cluster)
```

---

## 14. Vercel / platform mapping

| Local `.env` | Vercel | Notes |
|--------------|--------|-------|
| `NEXT_PUBLIC_*` | Production + Preview | Safe for browser |
| `STRIPE_SECRET_KEY` | Production only | Server-only |
| `SESSION_SECRET` | Production only | Required at runtime |
| `VITE_MAPBOX_TOKEN` | Kairo frontend | Build-time |

Reference deployments (public):  
`VERCEL_DEPLOYMENT_1=https://v2-0-bay.vercel.app/`

---

## Changelog

| Date | Change |
|------|--------|
| 2026-06-13 | Initial 10k-agent + APN + DePIN catalog |
| 2026-06-15 | Stripe 1% fee, Council Wishlist, Infura/Ankr RPC vars |

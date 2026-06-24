# Vault Internal Information Chain — Cross-Chain SDK & Repo Manifest

> Store this manifest in Vault at `yieldswarm/meta/scraper-manifest` (JSON).  
> **Never** store live API keys in this doc — use Vault KV paths only.

---

## Vault KV layout (DePIN + multi-chain)

| Path | Keys | Used by |
|------|------|---------|
| `yieldswarm/cloud/iotex` | `device_id`, `w3bstream_endpoint`, `project_token` | `/api/iotex/ingest` |
| `yieldswarm/cloud/runpod` | `api_key` | RunPod burst |
| `yieldswarm/cloud/vast` | `api_key` | Vast.ai training |
| `yieldswarm/cloud/azure` | `client_id`, `client_secret`, `subscription_id` | Grass / control plane |
| `yieldswarm/cloud/vercel-ai-gateway` | `api_key` | AI Gateway fallback |
| `yieldswarm/rpc/ton` | `api_key` | TON PoE settlement |
| `yieldswarm/rpc/solana` | `http_url`, `ws_url` | Emission router |
| `yieldswarm/data/neon` | `database_url` | DePIN profiles |

Bootstrap: `vault/setup/05-seed-secrets.sh` or `make seed-vault`.

---

## Category 1 — Core DePIN & chain SDKs

| Repo | SDK / use |
|------|-----------|
| https://github.com/ton-org/ton-core | TVM cells, BOC signing |
| https://github.com/ton-blockchain/ton | TON node RPC |
| https://github.com/iotexproject/iotex-core | IoTeX state |
| https://github.com/iotexproject/w3bstream | DePIN ingestion |
| https://github.com/iotexproject/pebble-firmware | Pebble hardware |
| https://github.com/helium/helium-program | Helium mobile / HNT |

---

## Category 2 — YieldSwarm + edge orchestration

| Repo | SDK / use |
|------|-----------|
| https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2 | This monorepo |
| https://github.com/basetenlabs/openclaw-baseten | OpenClaw workers |
| https://github.com/vercel/ai | Vercel AI SDK / Gateway |
| https://github.com/neondatabase/serverless | Neon edge driver |

---

## Category 3 — Security / audit targets

| Repo | Use |
|------|-----|
| https://github.com/crytic/slither | Static analysis |
| https://github.com/ton-blockchain/bug-bounty | TON scope |
| https://github.com/slowmist/DeFi-Vulnerabilities | DeFi patterns |

---

## Category 4 — Cross-chain bridges (granular DeFi pain points)

| SDK | Chains | Pain point solved |
|-----|--------|-------------------|
| Wormhole NTT | TON, Solana, EVM | Liquidity fragmentation |
| TonConnect | TON ↔ client | Wallet auth |
| Jupiter v6 | Solana | Swap routing |
| Uniswap v4 hooks | EVM | Custom settlement |

Wire via `backend/src/adapters/` and `config/domains.json` (17-domain edge).

---

## Scraper initialization (no secrets in command)

```bash
python3 -m scraper_engine run \
  --targets-file=docs/VAULT_DEPIN_INFO_CHAIN.md \
  --output-bucket=yieldswarm-telemetry \
  --depth=2 \
  --filter-keywords="rate-limit,telemetry-skew,oidc-validation"
```

---

## 17-domain routing

See `config/domains.json`. Health probe: `GET /healthz` on each domain.

Consensus origin block: `node scripts/helix-consensus-runner.mjs 100`

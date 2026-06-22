# YieldSwarm AgentSwarm OS v2.0

## Overview

**Jacuzzi-Helix 14-Lane Solenoid** — turquoise energy flow woven through pentagram + quadrilateral lanes (3-way running, 4×5×14 dimensions). Live site: [yieldswarm-v2.vercel.app](https://yieldswarm-v2.vercel.app)

10,080 AI Agents across 120 Cron Jobs  
Kimiclaw Consensus Council + SuperGrok Strategy Layer  
Helix Chain + Hydrogen Particle Accelerated Shading Tree  
$APN on Pump.fun · Unstoppable Domains integration

### Site map (L0–L6)

| Route | Layer | Purpose |
|-------|-------|---------|
| `/` | L0–L6 | Jacuzzi-Helix hero, 14-lane solenoid, live metrics |
| `/sales` | L3 Revenue | Z15 Pro bundles + **$5 payment rail test** |
| `/marketplace` | L3+L5 | 5-tier marketplace + NFT license keys |
| `/council/status` | L1 Council | SepETH DAO + Helix live data |
| `/payments` | L3 | Wise + Stripe + Web3 unified rails |
| `/arena` | L2 | Telemetry dashboard |

### Payment tests

```bash
# $5 Wise + on-chain test (logs to Neon when NEON_DATABASE_URL set)
curl -X POST https://yieldswarm-v2.vercel.app/api/revenue/z15-test \
  -H 'Content-Type: application/json' \
  -d '{"amountUsd":5,"product":"z15-rail-test"}'

# Live revenue metrics
curl https://yieldswarm-v2.vercel.app/api/revenue/metrics
```

Copy env: `cp deploy/env/layered.env.example .env` — see `docs/DEPLOYMENT_PRIORITY.md`.

### 55 God Tasks (SPLATTER TECH)

Full registry: `docs/GOD_TASKS_55.md` · Linear import: `docs/linear/god-tasks-import.csv`

```bash
./scripts/god-task.sh list          # all 55 tasks
./scripts/god-task.sh 55            # capstone deploy
./scripts/yieldswarm-deploy.sh --dry-run
```

## Mine With Us

Join the YieldSwarm harvest: point your miners and pool payouts at our **treasury + mining roots**, use our **RPC mesh** for chain reads, and run beside our **Bittensor node** on Akash.

Full RPC study: [`docs/RPC_ALCHEMY_STUDY.md`](docs/RPC_ALCHEMY_STUDY.md) · Operator pane: [`SINGLE_PANE_OF_GLASS.md`](SINGLE_PANE_OF_GLASS.md)

### Treasury and mining roots

Canonical manifest: `config/TREASURY_MANIFEST.json` (also in `agents/governance/gospel.py`).

| Key | Address | Use |
|-----|---------|-----|
| **Nexus Treasury (Solana)** | `kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN` | Primary on-chain treasury |
| **IoTeX hub** | `0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567` | IoTeX / Kairo driver yield |
| **BTC (IOPAY bridge)** | `bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8` | BTC payouts via IOPAY |
| **base_etc** | `0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00` | ETC mining root |
| **zec** | `t1KCti3km9DJLxYot3t7NgzYW2FpTnVCvrY` | Zcash mining root |
| **prl** | `29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9` | Pearl mining root |
| **tao** | `5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF` | TAO / Bittensor-related |
| **base_hype** | `0x856e90EDd6d167355FcB6c35a8A857FFCA011Aa0` | Base HYPE root |
| **base_cbeth** | `0x455156dFDc95084A8e84e8d734a036A9a2e11Af0` | Base cbETH root |
| **base_btc** | `0x1353f846DB707F6739591d294c80740607F1A87a` | Base BTC root |

Configure your pool **payout wallet** or **worker destination** to the matching root above. Revenue still flows through Great Delta **50/30/15/5** before settlement.

### RPC mesh (mine and verify on-chain)

```bash
export ALCHEMY_API_KEY=your_key_here   # Vault: yieldswarm/data/integrations/alchemy
export ALCHEMY_APP_NAME="Christopher's First App"

# Backend auto-fills unset RPC env vars (Solana, ETH, Base, Polygon, Arbitrum, Sepolia)
curl -s http://127.0.0.1:8080/api/rpc/alchemy/health | jq
curl -s http://127.0.0.1:8080/api/rpc/alchemy/defaults | jq
```

164-network catalog: `GET /api/rpc/alchemy/endpoints` · Setup: [`docs/ALCHEMY_CHRISTOPHERS_FIRST_APP.md`](docs/ALCHEMY_CHRISTOPHERS_FIRST_APP.md)

**Security:** Never commit `ALCHEMY_API_KEY`. Rotate if exposed.

### Bittensor node (join our subnet miner)

We run a Bittensor miner on **Akash RTX 3090** alongside Kairo DePIN telemetry.

```bash
# Vault + deploy (see docs/VAULT_AKASH_DEPLOY.md)
export BT_NETUID=1
export BT_NETWORK=finney
./vault/scripts/seed-secrets.sh          # yieldswarm/runtime/bittensor
eval "$(./scripts/akash-vault-prepare.sh bittensor-runtime)"
./scripts/deploy-bittensor.sh
```

| Item | Value |
|------|-------|
| SDL | `deploy/akash-bittensor-miner.sdl.yml` |
| Vault policy | `bittensor-runtime` |
| Default subnet | `BT_NETUID=1` on `finney` |
| PoW expansion | `POW_MINING_COINS=bittensor,grass` |

To mine **with** us (same subnet, shared infra docs): mirror the SDL, point emissions settlement at the **tao** root above, and register workers through `GET /api/telemetry/akash`.

### Tri-solenoid operator hooks

| Solenoid | API | Doc |
|----------|-----|-----|
| Nexus | `/api/nexus/*` | `docs/TRI_SOLENOID_ARCHITECTURE.md` |
| Helix | `/api/helix/status` | `onchain/programs/helix/` |
| Shadow / Arena | `/api/shadow/status` | `onchain/programs/arena/` |
| IoT Hub | `/api/iot/*` | `docs/IOT_HUB.md` |

```bash
python3 services/nexus/cli.py status
./scripts/activate-helix.sh
# or unified: npm run run-all-onchain
```

Launch manifest (all npm entrypoints): [`docs/LAUNCH_MANIFEST.md`](docs/LAUNCH_MANIFEST.md)

## Core AI Workspace
Odysseus is integrated as the central self-hosted YieldSwarm workspace and
agent-orchestration layer. It is the default interface for the 10,080 mutated
agents and 169 deities, backed by ChromaDB persistent memory and the
OpenAI-compatible LiteLLM router for Fireworks, OpenRouter, and Akash RTX 3090
Ollama workers.

Local stack:
```bash
cp .env.example .env
# Fill router/provider keys and Akash Ollama endpoints.
scripts/deploy-odysseus-stack.sh up
```

Open Odysseus at `http://localhost:7000`, then add the LiteLLM router as an
OpenAI-compatible provider using `http://localhost:4000/v1` and
`YIELDSWARM_ROUTER_API_KEY`.

Akash stack:
```bash
scripts/build-odysseus-images.sh
PUSH=true scripts/build-odysseus-images.sh
scripts/deploy-odysseus-stack.sh render-akash
```

The Akash SDL template is at `deploy/akash-odysseus.sdl.yml`; rendered SDL files
are written under `deploy/rendered/` and ignored by Git.

See `docs/odysseus-yieldswarm.md` for model aliases, memory bootstrap steps,
and Akash Ollama worker requirements.

Full local Odysseus stack (LiteLLM + ChromaDB + SearXNG + ntfy):
```bash
docker compose -f docker-compose.yml -f docker-compose.odysseus.yml up -d
```

## Kairo (Driver → YieldSwarm DePIN Node)

Every Kairo driver gets a persistent IoTeX + EVM compatible cryptographic identity.
Signed telemetry routes into the Mandelbrot / Tree of Life architecture.

```bash
pip install -r requirements.txt
python kairo/cli.py register
# Dashboard: http://localhost:8080/kairo/ (via integration backend)
```

API: `POST /api/kairo/drivers/register`, `POST /api/kairo/telemetry/ingest`

## Domains

See `DOMAINS.md` for Unstoppable Domains + Cloudflare wiring (app, api, kairo subdomains).

## Documentation

| Doc | Purpose |
|-----|---------|
| `SINGLE_PANE_OF_GLASS.md` | Helix + tri-solenoid + RPC mesh (Mermaid) |
| `docs/RPC_ALCHEMY_STUDY.md` | 164-network Alchemy RPC study |
| `docs/TRI_SOLENOID_ARCHITECTURE.md` | Nexus · Helix · Shadow solenoids |
| `docs/ALCHEMY_CHRISTOPHERS_FIRST_APP.md` | Alchemy setup + Vault |
| `docs/ARCHITECTURE.md` | Full + investor architecture diagrams |
| `INTEGRATION_REPORT.md` | 16-prong status matrix |
| `PRODUCTION_READINESS.md` | Final smoke tests + mainnet checklist |
| `KAIRO_FRONTEND.md` | Kairo app architecture + Vercel deploy |
| `MERGE_STRATEGY.md` | Branch strategy + merge commands |
| `DEPLOY.md` | Production deployment runbook |
| `DOMAINS.md` | Unstoppable Domains wiring |

## Deployment
- Odysseus stack: `docker-compose.yml`
- Akash SDL: `deploy/akash-odysseus.sdl.yml`
- Vercel: https://v2-0-bay.vercel.app/
- Project: https://vercel.com/support-6930s-projects/v2-0/c64SWNEkWaF39C4GcjFPYoLxWgMg
- Odysseus GPU service:
  - Akash SDL: `deploy/akash/odysseus.sdl.yml`
  - Docker: `Dockerfile`, `docker-compose.yml`, `docker/entrypoint-odysseus.sh`
  - Build workflow: `.github/workflows/build-odysseus.yml`
  - Vault Terraform: `terraform/odysseus/`
  - Production deploy: `scripts/deploy-production-odysseus.sh`

## Setup
1. Copy .env.example to .env
2. Fill in non-secret values securely
3. Store API keys, model hosts, model API keys, and deploy credentials in HashiCorp Vault
4. Deploy to Vercel, Azure, or Akash
5. Wire Unstoppable Domains via Cloudflare nameservers

## HashiCorp Vault
Odysseus deployment artifacts use Vault as the secret source of truth. Keep only
Vault coordinates and workload identity settings in environment variables.

Expected runtime path:
- `kv/data/yieldswarm/odysseus/runtime`
  - `ODYSSEUS_API_KEY`
  - `ODYSSEUS_MODEL_HOST`
  - `ODYSSEUS_MODEL_API_KEY`

Expected deployment path:
- `kv/data/yieldswarm/odysseus/deploy`
  - `image_repository`
  - `AKASH_KEY_NAME`
  - `AKASH_CHAIN_ID`
  - `AKASH_NODE`
  - `AKASH_FEES`

Initialize Vault policy and JWT roles with:
```bash
cd terraform/odysseus
terraform init
terraform apply \
  -var='vault_addr=https://vault.example.com' \
  -var='github_repository=owner/repo'
```

Render or deploy Odysseus with:
```bash
scripts/deploy-production-odysseus.sh render-akash
scripts/deploy-production-odysseus.sh akash
```

## Odysseus YieldSwarm Tools
YieldSwarm tool definitions live in `agents/yieldswarm_tools/` and cover:
- Akash lease management
- Treasury 50/30/15/5 rebalancing
- On-chain emission router queries
- Multi-chain wallet operations through the unified wallet SDK
- Real-time Akash worker telemetry

Odysseus can consume them as native function tools:

```python
from agents.yieldswarm_tools.odysseus import register_yieldswarm_tools

register_yieldswarm_tools(
    function_tool_schemas=FUNCTION_TOOL_SCHEMAS,
    tool_handlers=TOOL_HANDLERS,
    tool_tags=TOOL_TAGS,
    builtin_tool_descriptions=BUILTIN_TOOL_DESCRIPTIONS,
)
```

Or register the built-in MCP server:

```python
"yieldswarm": ("mcp_servers/yieldswarm_server.py", "Built-in: YieldSwarm")
```

Mutating operations default to `dry_run=true`. Configure the adapter endpoints and
wallet SDK module in `.env` before enabling live lease, wallet, or treasury actions.

## Odysseus Cookbook Model Routing

YieldSwarm now includes an Akash RTX 3090 model router for Odysseus
Cookbook inference placement.

### Updated routing logic

The router lives in `services/yieldswarm_model_router.py` and is exposed by
`api/yieldswarm_model_routing.py`.

1. Read Akash RTX 3090 worker state from `YIELDSWARM_AKASH_WORKERS`, or create
   `YIELDSWARM_RTX3090_WORKER_COUNT` default workers with 24GB VRAM and a 2GB
   runtime reserve.
2. Read `YIELDSWARM_MODEL_CATALOG`, or use the built-in RTX 3090 catalog:
   Phi 3.5 Mini Q6, Mistral 7B Q5, Llama 3.1 8B Q5, Qwen2.5 Coder 7B Q5,
   DeepSeek R1 Distill 8B Q5, and Mixtral 8x7B Q4.
3. Score every task-compatible model/worker route using:
   - available VRAM after load,
   - model quality and throughput,
   - current worker queue and active request pressure,
   - Great Delta emission score (`GreatDeltaEmissionLogic`),
   - agent mutation fit (`AgentMutationScorer`),
   - a loaded-model bonus and eviction/load penalties.
4. Recommend the highest-scoring route. If the model is already resident, the
   route action is `serve`. If it fits in free VRAM, the action is `load`. If
   idle models must be removed first, the action is `evict_then_load` with
   `unload_before_load` populated.
5. `route_request(..., autoload=True)` dynamically loads the recommended model,
   unloads idle lower-value models when needed, marks the request active, and
   returns the worker/model provider route.
6. `rebalance()` accepts current swarm workload weights and worker pressure,
   preloads models for hot tasks, and unloads idle models from saturated
   workers.

Run the optimizer recommendation snapshot:

```bash
python agents/akash-optimizer.py
```

Run the local routing API:

```bash
python api/yieldswarm_model_routing.py
```

### New API endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Health check for the model routing API. |
| `GET` | `/api/yieldswarm/models` | Return the active model catalog and VRAM budgets. |
| `GET` | `/api/yieldswarm/workers` | Return Akash RTX 3090 worker VRAM, queue, health, and loaded models. |
| `GET` | `/api/yieldswarm/models/recommend?task=chat&agent_id=a1&priority=0.7&mutation_score=0.6` | Recommend the best model route without mutating load state. |
| `GET` | `/api/yieldswarm/models/routes?task=coding` | Return all scored candidate routes for a task. |
| `POST` | `/api/yieldswarm/infer/route` | Select and optionally autoload the best route for an inference request. |
| `POST` | `/api/yieldswarm/infer/complete` | Mark a routed request complete so active counts can drain. |
| `POST` | `/api/yieldswarm/models/load` | Explicitly load a model on a selected or best-fit worker. |
| `POST` | `/api/yieldswarm/models/unload` | Unload an idle model from a selected worker or all workers. |
| `POST` | `/api/yieldswarm/workload/rebalance` | Adjust loaded models based on current swarm task weights and worker pressure. |

Example route request:

```json
{
  "task": "coding",
  "agent_id": "deity-agent-17",
  "priority": 0.8,
  "mutation_score": 0.72,
  "autoload": true
}
```

## Frontend workspaces
- Arena: `frontend/arena/index.html` provides a unified telemetry dashboard for Akash workers and the Odysseus agent/memory system.
- Portal: `frontend/portal/index.html` embeds or links the Odysseus workspace for advanced agent interaction and deep research.
- Shared modules in `frontend/shared/` resolve runtime config, request a YieldSwarm session, create Odysseus SSO handoff URLs, and normalize telemetry feeds.

### Required backend contracts
- `GET ${AKASH_TELEMETRY_URL:-/api/telemetry/akash}` returns Akash worker, lease, deployment, or node metrics.
- `GET ${ODYSSEUS_TELEMETRY_URL:-/api/telemetry/odysseus}` returns Odysseus agents, research queue, and memory/vector metrics.
- `GET ${YIELDSWARM_AUTH_SESSION_URL:-/api/auth/session}` returns the current YieldSwarm session when a user is signed in.
- `POST ${YIELDSWARM_AUTH_HANDOFF_URL:-/api/auth/odysseus/handoff}` returns either `redirectUrl` or a short-lived `handoffToken`/`sessionId` accepted by Odysseus.

Set matching meta tags or `window.YIELDSWARM_CONFIG` values when these endpoints are hosted somewhere other than the same origin.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Frontend & Unified Wallet
The `frontend/` app is a Vite + React + TypeScript dApp with a production-grade,
custom multi-chain wallet layer (`frontend/src/wallet`) supporting EVM
(viem + wagmi), Solana, TON, and basic Bitcoin. It is the default wallet layer
used across Arena, Portal, and Payments. See `frontend/README.md` for details.

```bash
cd frontend && npm install && npm run dev
```

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.

---

# Payments App

A full payment-rails application (Next.js App Router + TypeScript + Tailwind) lives at the
repo root. It exposes a single **Payments page** (`/payments`) plus backend API routes that let
users deposit and withdraw across fiat and crypto rails:

- **Square** — fiat deposits via **card** (hosted Square Checkout or embedded Web Payments SDK)
  and **ACH** bank transfer, settled by a signature-verified webhook.
- **Wise** — fiat **payouts/transfers** (off-ramp: quote → recipient → transfer → fund) and
  inbound **payment requests** (on-ramp), with RSA-verified webhooks.
- **Web3 on/off ramps** — a unified wallet-connect system using **viem** + **ethers.js** (EVM),
  **@solana/web3.js** (Solana), and **@tonconnect** (TON). Deposits are detected on-chain;
  withdrawals send to any wallet address.

## Run

```bash
npm install
cp .env.example .env        # fill in the PAYMENT RAILS APP section
npm run dev                 # http://localhost:3000/payments
```

Scripts: `npm run dev | build | start | lint | typecheck | test`.

## Architecture

```
src/
  app/
    payments/page.tsx              # the single Payments page
    api/
      config, balance              # public config + user balances/activity
      wallets, wallets/nonce       # link a wallet by signing a challenge
      deposits/square              # card (checkout|payment) + ACH
      deposits/wise                # inbound payment request
      deposits/web3, .../verify    # start intent + on-chain detection/credit
      withdrawals/bank             # Wise off-ramp to a bank account
      withdrawals/web3             # send crypto to any wallet
      webhooks/square, webhooks/wise  # signature-verified settlement
  lib/
    payments/square.ts, wise.ts    # rail SDKs + webhook verification
    web3/                          # chains, deposit-detection, withdraw, signatures
    ledger.ts                      # atomic balance + transaction ledger
    db/store.ts                    # pluggable store (memory|file → Neon/Postgres)
    auth/                          # anonymous HMAC session + wallet nonces
```

## How money flows

- **Deposit (Square)**: create a pending tx → hosted checkout or tokenized card/ACH payment →
  Square webhook (`payment.updated`) is HMAC-verified → balance credited once on `COMPLETED`.
- **Deposit (Wise)**: create a Wise payment request → user pays → `balances#credit` webhook
  (RSA-verified) credits the balance.
- **Deposit (Web3)**: `POST /api/deposits/web3` returns the treasury address + an intent →
  user sends from a connected wallet (or pastes a tx hash) → `/verify` independently confirms
  the transfer to treasury and credits once it has `ONCHAIN_MIN_CONFIRMATIONS`.
- **Withdraw (bank)**: funds are atomically reserved, then a Wise payout is created and funded;
  on failure the reservation is refunded.
- **Withdraw (wallet)**: funds are reserved, then sent via ethers (EVM) / @solana/web3.js
  (Solana) to the destination address; refunded on failure.

## Webhook verification

- **Square**: `x-square-hmacsha256-signature` validated with `WebhooksHelper` over the raw body
  and notification URL (`SQUARE_WEBHOOK_SIGNATURE_KEY`).
- **Wise**: `X-Signature-SHA256` validated as RSA-SHA256 over the raw body using
  `WISE_WEBHOOK_PUBLIC_KEY`.

Both handlers are idempotent (dedupe on the provider event id).

## Notes / production hardening

- The default store is in-memory (per-process). Implement the `Store` interface in
  `src/lib/db/store.ts` against Neon/Postgres for durable, multi-instance persistence.
- Set dedicated EVM RPC URLs (Alchemy/Infura) — public RPCs may rate-limit or block.
- Configure `TREASURY_*` and `HOT_WALLET_*` for on/off-ramp; SPL-token and TON sends require
  additional libs (`@solana/spl-token`, `@ton/ton`) and are gated with clear errors.
- Auth is an anonymous signed-cookie session; swap `getCurrentUser` for a real auth provider.
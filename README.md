# YieldSwarm AgentSwarm OS v2.0

## Overview
10,080 AI Agents across 120 Cron Jobs
Kimiclaw Consensus Council + SuperGrok Strategy Layer
Helix Chain + Hydrogen Particle Accelerated Shading Tree
$APN on Pump.fun
Unstoppable Domains integration

## Deployment
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
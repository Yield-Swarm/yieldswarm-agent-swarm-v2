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

## Setup
1. Copy .env.example to .env
2. Fill in values securely
3. Deploy to Vercel or Azure
4. Wire Unstoppable Domains via Cloudflare nameservers

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

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
# Production Revenue Checklist

> Align `production` branch with `main`, then configure Vercel (or your host) so payment rails can settle real funds.

## 1. Branch promotion

```bash
git fetch origin
./scripts/sync-environment-branches.sh
```

This fast-forwards `production` (and other env branches) to `main` when they are not ahead.

**Current deploy target:** Vercel project linked to the `production` branch (see `BRANCHES.md`).

## 2. Required Vercel production env vars

| Variable | Purpose |
|----------|---------|
| `SESSION_SECRET` | Auth sessions (required at runtime in production) |
| `APP_URL` | Canonical site URL, e.g. `https://yieldswarm.crypto` |
| `NEXT_PUBLIC_APP_URL` | Same URL for client-side redirects |
| `STRIPE_SECRET_KEY` | Live secret key (`sk_live_…`) |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Live publishable key (`pk_live_…`) |
| `STRIPE_WEBHOOK_SECRET` | Signing secret from Stripe Dashboard webhook |

### Strongly recommended

| Variable | Purpose |
|----------|---------|
| `PAYMENTS_STORE_DRIVER` | Use durable storage — `memory` loses balances on cold start / across serverless instances |
| `SQUARE_ACCESS_TOKEN` / `SQUARE_LOCATION_ID` | Card/ACH deposits via Square |
| `WISE_API_TOKEN` | Fiat payouts |
| `TREASURY_EVM_ADDRESS` / `TREASURY_SOLANA_ADDRESS` | Web3 deposit treasury |

> **Note:** Built-in store drivers are `memory` (default) and `file`. For durable multi-instance production, implement Postgres/Neon in `src/lib/db/store.ts` per README.

## 3. Stripe webhook (required for revenue)

1. Stripe Dashboard → Developers → Webhooks → Add endpoint
2. URL: `https://<your-domain>/api/webhooks/stripe`
3. Events:
   - `checkout.session.completed`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
4. Copy signing secret → `STRIPE_WEBHOOK_SECRET` in Vercel

## 4. Revenue rails on this release

| Rail | Route / page | Fee model |
|------|--------------|-----------|
| **Stripe** | `/payments`, `/api/deposits/stripe`, `/api/webhooks/stripe` | 1% platform fee on top of credit (`PLATFORM_FEE_RATE = 0.01`) |
| **Square** | `/api/webhooks/square` | Card/ACH deposits |
| **Wise** | `/api/withdrawals/bank`, `/api/webhooks/wise` | Fiat payouts |
| **Web3** | `/api/withdrawals/web3` | On-chain deposits/withdrawals |
| **Kairo** | `/api/kairo/fare`, `/api/webhooks/kairo` | 1% customer fee, 2× driver pay |

Fee logic: `src/lib/payments/fees.ts`, `src/lib/kairo/fees.ts`.

## 5. Smoke test after deploy

1. Open `/payments` on production domain
2. Create a small Stripe test charge (use live keys only when ready)
3. Confirm webhook returns `200` in Stripe Dashboard
4. Verify user balance credits **net** amount (total charge minus 1% fee)
5. Check `/api/telemetry/*` and `/arena` if monitoring revenue-adjacent ops

## 6. Validation before promotion

```bash
npm run test:unit    # 18 tests
npm run test:python
npm run build
```

All three must pass on the `main` tip before syncing `production`.

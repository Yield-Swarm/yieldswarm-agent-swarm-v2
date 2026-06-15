# Kairo Frontend — Architecture & Deployment

Kairo is the consumer-facing driver marketplace integrated with YieldSwarm DePIN rewards and payment rails.

---

## Stack

| Layer | Technology | Path |
|-------|------------|------|
| App shell | Vite (vanilla JS) | `kairo/app/` |
| Maps | Mapbox GL JS v3.6 | `kairo/app/src/main.js` |
| API | Backend integration server | `http://localhost:8787/api/kairo/*` |
| Payments | YieldSwarm ledger (1% fee) | `src/lib/payments/fees.ts` |
| Identity | Kairo crypto wallets | `kairo/identity/` |
| Deploy | Vercel | `vercel.json` → `kairo/app/dist` |

---

## Features

### Rider flow
1. Open app → Mapbox shows pickup (geolocation or manual)
2. Enter destination → fare estimate with **1% platform fee** breakdown
3. Book ride → matches driver → Square checkout (via payments API)

### Driver flow
1. Register via `POST /api/kairo/drivers/register` → IoTeX + EVM identity
2. Drive → signed telemetry via `POST /api/kairo/telemetry/ingest`
3. Earnings dashboard: **2× base pay** + DePIN rewards from Mandelbrot scoring

---

## Environment Variables

| Variable | Where | Purpose |
|----------|-------|---------|
| `VITE_MAPBOX_TOKEN` | Vercel / `.env` | Mapbox GL access token |
| `VITE_API_BASE` | Vercel / `.env` | API base (default `/api/kairo`) |
| `MAPBOX_ACCESS_TOKEN` | Vault `yieldswarm/kairo/config` | Server-side geocoding (future) |
| `KAIRO_WEBHOOK_SECRET` | Vault `yieldswarm/payments/kairo` | Order settlement webhooks |

---

## Local Development

```bash
# Terminal 1 — backend
cd backend && npm install && npm start   # :8787

# Terminal 2 — Kairo app
cd kairo/app
export VITE_MAPBOX_TOKEN=pk.your_token
export VITE_API_BASE=http://localhost:8787/api/kairo
npm install && npm run dev   # :5173
```

Dashboard (contributions only): `http://localhost:8787/kairo/`

---

## Vercel Deployment

```bash
# From repo root — vercel.json builds kairo/app
vercel --prod

# Or link in Vercel dashboard:
# Build: cd kairo/app && npm install && npm run build
# Output: kairo/app/dist
```

Set env vars in Vercel project settings:
- `VITE_MAPBOX_TOKEN`
- `VITE_API_BASE=https://api.yieldswarm.crypto/api/kairo`

---

## Domain Wiring

See `DOMAINS.md`:
- `kairo.<domain>` → Vercel deployment
- `api.<domain>` → backend integration server (Kairo API routes)

---

## API Contracts

### `POST /api/kairo/drivers/register`
```json
{ "deviceFingerprint": "optional-device-id" }
```
Response: `{ "driver_id", "evm_address", "iotex_address", "public_key_hex" }`

### `POST /api/kairo/telemetry/ingest`
Signed event envelope (see `kairo/identity/verify.py`).

### `GET /api/kairo/contributions?limit=25`
Driver contribution stats + estimated rewards.

### `POST /api/webhooks/kairo`
Kairo order settlement — requires `x-kairo-signature` HMAC header.

---

## Fee Display Logic

```javascript
const FEE_PERCENT = 0.01;      // 1% customer fee
const DRIVER_MULTIPLIER = 2;   // 2× driver pay
```

Matches server-side `src/lib/payments/fees.ts` and `driver-payout.ts`.

---

## Next Steps

1. Add React Router for ride history + driver mode toggle
2. Wire Square Payment Form from `src/components/payments/`
3. Real-time driver location via Mapbox + signed telemetry stream
4. Share `frontend/src/wallet/` for in-app Web3 treasury display

# KAIRO_FRONTEND.md — Customer & Driver App

## Overview

The Kairo frontend is a static ride/delivery shell deployable to **Vercel** or **Netlify**, wired to the YieldSwarm Kairo API and payment rails.

| Surface | Path | URL (local) |
|---------|------|-------------|
| Customer/driver app | `kairo/frontend/index.html` | `/kairo-app/` (via integration backend) |
| Contribution dashboard | `kairo/dashboard/contribution.html` | `/kairo/contribution.html` |
| API proxy | `backend/src/routes/kairo.js` | `/api/kairo/*` |

## Features

- **Mapbox** live map (dark style) — set `MAPBOX_TOKEN`
- **1% platform fee** display on every fare quote
- **2× driver pay** estimate
- **Signed telemetry** submission to Mandelbrot pipeline
- **Earnings breakdown** — app revenue + DePIN rewards

## Local development

```bash
# Terminal 1 — Kairo Python API
pip install -r requirements.txt
python -m kairo.api.routes

# Terminal 2 — Integration backend (serves frontend + proxies API)
cd backend && npm install && npm start

# Open
open http://localhost:8080/kairo-app/
```

Inject Mapbox token in the browser console or via `kairo/frontend/config.js`:

```html
<script>
  window.KAIRO_CONFIG = {
    apiBase: '/api/kairo',
    mapboxToken: 'pk.eyJ...'
  };
</script>
```

## Vercel deployment

```bash
# From repo root
vercel --cwd kairo

# Required env vars (Vercel dashboard or Vault → Vercel sync)
KAIRO_API_BASE=https://api.yieldswarm.crypto/api/kairo
MAPBOX_TOKEN=pk.eyJ...
```

`kairo/vercel.json` routes all paths to the static frontend.

## Netlify deployment

```toml
# netlify.toml (repo root or kairo/)
[build]
  publish = "kairo/frontend"

[[redirects]]
  from = "/api/*"
  to = "https://api.yieldswarm.crypto/api/:splat"
  status = 200
  force = true
```

## Payment integration

Kairo uses the shared YieldSwarm payment rails:

| Flow | Module |
|------|--------|
| Card / ACH deposit | `src/lib/payments/square.ts` |
| Bank transfer / cashout | `src/lib/payments/wise.ts` |
| On-chain wallet | `frontend/src/wallet/`, `src/lib/web3/` |

Fee model (env-configurable):

```bash
KAIRO_CUSTOMER_FEE_RATE=0.01
KAIRO_DRIVER_PAY_MULTIPLIER=2.0
```

## DNS

Point `kairo.yieldswarm.crypto` (or `app.kairo.crypto`) to Vercel — see `DOMAINS.md`.

## Unstoppable Domains

Website record → Vercel deployment URL. Crypto records for treasury wallets are separate from the app.

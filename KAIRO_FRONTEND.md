# KAIRO_FRONTEND.md — Customer & Driver App

## Overview

The Kairo frontend is a static ride/delivery shell deployable to **Vercel** or **Netlify**, wired to the YieldSwarm Kairo API and payment rails.

| Surface | Path | URL (local) |
|---------|------|-------------|
| Customer/driver app | `kairo/frontend/index.html` | `/kairo-app/` (via integration backend) |
| Contribution dashboard | `kairo/dashboard/contribution.html` | `/kairo/contribution.html` |
| API proxy | `backend/src/routes/kairo.js` | `/api/kairo/*` |

## Features

- **Mapbox** live map with route line (geocode + Directions API)
- **Fare quote** via `POST /api/kairo/fare/quote` (distance + duration)
- **Request ride** via `POST /api/kairo/rides` with loading / success / error states
- **1% platform fee** + **2× driver pay** from server-side calculation
- **DePIN status** pill — pending until Akash workers are live (`GET /api/kairo/depin/status`)
- **Signed telemetry** submission to Mandelbrot pipeline
- **Runtime config** from `/kairo-app/config.js` (no hardcoded localhost)

## Environment variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `MAPBOX_TOKEN` or `VITE_MAPBOX_TOKEN` | Yes (for map) | Geocoding, directions, live map |
| `KAIRO_PUBLIC_API_BASE` | Production | Public API URL e.g. `https://api.yieldswarm.crypto/api/kairo` |
| `KAIRO_API_BASE` | Backend server | Upstream Python Kairo API (default `http://127.0.0.1:8091`) |

When served from integration backend (`:8080`), open `/kairo-app/` — config is injected automatically.

## Local development

```bash
# Terminal 1 — Kairo Python API
pip install -r requirements.txt
python -m kairo.api.routes

# Terminal 2 — Integration backend (serves frontend + proxies API)
export MAPBOX_TOKEN=pk.eyJ...
cd backend && npm install && npm start

# Open
open http://localhost:8080/kairo-app/
```

## Vercel deployment

Deploy the **integration backend** (Render/Akash) with `MAPBOX_TOKEN` set, then point Kairo static hosting at the API:

```bash
# Integration backend (Render) env:
KAIRO_PUBLIC_API_BASE=https://api.yieldswarm.crypto/api/kairo
MAPBOX_TOKEN=pk.eyJ...
KAIRO_API_BASE=http://127.0.0.1:8091  # or internal Python service URL

# Or serve full stack from integration server — users hit:
# https://api.yieldswarm.crypto/kairo-app/
```

`kairo/vercel.json` is for static-only deploys — prefer integration backend for `/api/kairo` proxy.

## API routes (integration backend)

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/kairo/fare/quote` | Fare breakdown from `distanceKm` / `durationMin` |
| `POST` | `/api/kairo/rides` | Create ride request |
| `GET` | `/api/kairo/rides/:id` | Poll ride status |
| `GET` | `/api/kairo/depin/status` | Akash worker connectivity |
| `POST` | `/api/kairo/telemetry` | Signed driver telemetry |
| `GET` | `/api/kairo/drivers/:id/contribution` | Earnings + DePIN |

See `docs/KAIRO_AKASH_COORDINATION.md` for parallel Akash deploy track.

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

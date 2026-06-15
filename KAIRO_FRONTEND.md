# KAIRO_FRONTEND.md — Driver-First Consumer App

Kairo is the customer-facing ride/delivery app integrated with YieldSwarm DePIN
telemetry and payment rails.

---

## Architecture

```
kairo/frontend/          Vite + React (Mapbox, 1% fee UI, 2× driver pay)
kairo/backend/           FastAPI (crypto identity, signed telemetry)
kairo/models/            Fare + earnings schemas
src/app/api/kairo/       Next.js payment rail integration (shared monorepo)
src/lib/kairo/fees.ts    Fee calculation (1% customer, 2× driver)
```

Each Kairo driver is a **YieldSwarm DePIN node**: persistent IoTeX + EVM identity,
cryptographically signed telemetry routed into the Mandelbrot / Tree of Life mesh.

---

## Quick start (local)

### 1. Kairo backend (identity + telemetry)

```bash
cd kairo/backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export KAIRO_API_PORT=8100
python -m kairo.backend.server
# Health: http://127.0.0.1:8100/health
```

### 2. Kairo frontend

```bash
cd kairo/frontend
npm install
export VITE_KAIRO_API_URL=http://127.0.0.1:8100
export VITE_MAPBOX_TOKEN=your_mapbox_token   # optional; fallback UI without map
npm run dev
# Open http://localhost:5174
```

### 3. Payment rails (monorepo root)

```bash
cp .env.example .env   # fill Square, Wise, Web3 keys via Vault
npm install && npm run dev
# Payments: http://localhost:3000/payments
# Kairo fare API: http://localhost:3000/api/kairo/fare
```

---

## Features

| Feature | Location | Notes |
|---------|----------|-------|
| 1% customer flat fee | `App.tsx`, `src/lib/kairo/fees.ts` | Shown in fare breakdown |
| 2× driver app pay | Same | Base fare × 2 |
| DePIN reward estimate | `mandelbrot.py`, contribution panel | $0.02 per contribution point |
| Mapbox live tracking | `components/MapView.tsx` | Requires `VITE_MAPBOX_TOKEN` |
| Crypto identity | `identity.py` | EVM + IoTeX from single secp256k1 key |
| Signed telemetry | `telemetry.py` | ECDSA sign → Mandelbrot shard routing |
| Instant cashout flag | UI + payment rails | Wire to Square/Wise withdraw APIs |

---

## Deployment

### Vercel (recommended for frontend)

```bash
cd kairo/frontend && npm run build
# Deploy dist/ to Vercel or Netlify
# Set env: VITE_KAIRO_API_URL=https://kairo-api.yourdomain
# Set env: VITE_MAPBOX_TOKEN (from Vault)
```

### Akash (Kairo API alongside swarm)

Add Kairo service to `deploy/deploy-swarm-monolith.yaml` or run as sidecar.
Secrets injected via `vault/policies/kairo-runtime.hcl` + Vault Agent.

---

## API reference

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/drivers/identity` | Create driver crypto identity |
| GET | `/api/v1/drivers/{id}/identity` | Public identity + contribution |
| POST | `/api/v1/telemetry` | Submit signed driving telemetry |
| GET | `/api/v1/drivers/{id}/contribution` | DePIN contribution stats |
| POST | `/api/kairo/fare` | Fare breakdown (Next.js, payment rails) |

---

## YieldSwarm integration points

- **Wallet layer:** `frontend/src/wallet/` — reuse for driver crypto payouts
- **Payments:** `src/lib/payments/` — Square deposit, Wise bank, Web3 on-ramp
- **Vault:** `kv/yieldswarm/kairo/runtime` — Mapbox, API keys, identity encryption
- **Odysseus memory:** telemetry forwarded to ChromaDB when `ODYSSEUS_CHROMA_URL` set
- **Mandelbrot routing:** `kairo/backend/mandelbrot.py` — Tree of Life shard assignment

---

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `VITE_MAPBOX_TOKEN` | For live map | Mapbox GL access token |
| `VITE_KAIRO_API_URL` | Prod | Kairo backend base URL |
| `KAIRO_API_PORT` | Backend | Default 8100 |
| `KAIRO_IDENTITY_STORE` | Backend | Path for encrypted identity store |
| `KAIRO_DEPIN_REWARD_RATE` | Backend | USD per contribution point (default 0.02) |
| `ODYSSEUS_CHROMA_URL` | Optional | Forward telemetry to Odysseus mesh |

All secrets should be sourced from HashiCorp Vault at runtime — see `SECRETS.md`.

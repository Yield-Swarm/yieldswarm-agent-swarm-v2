# KAIRO_FRONTEND.md — Ride/Delivery App Deployment

## Overview

Kairo is the consumer-facing ride and delivery app integrated with YieldSwarm's
DePIN intelligence layer. It lives at `/kairo` in this monorepo.

| Component | Path | Deploy target |
|-----------|------|---------------|
| Frontend (Mapbox) | `kairo/frontend/index.html` | Vercel `/kairo` |
| API (identity + telemetry) | `kairo/api/main.py` | Akash or local `:8787` |
| Crypto identity | `kairo/models/identity.py` | Runtime |
| Mandelbrot pipeline | `kairo/services/pipeline.py` | Akash workers |

---

## Features

- **Ride & delivery tabs** with mode switching
- **Mapbox live tracking** (dark theme, geolocation marker)
- **1% customer fee** badge displayed in header
- **2× driver pay** + DePIN earnings breakdown
- **Signed telemetry** ingested to Mandelbrot shard routing
- **IoTeX + EVM** compatible driver identities

---

## Deployment URLs

| Environment | URL | Branch |
|-------------|-----|--------|
| Production | `https://app.kairo.x` | `MAINNET` |
| Staging | `https://app.kairo.x` (Vercel preview) | `production` |
| Dev | `https://v2-0-bay.vercel.app/kairo` | `development` |
| Local | `http://localhost:5173/kairo` | any |

Configure domains in `DOMAINS.md` (rows 3–4: `kairo.x`, `kairo.crypto`).

---

## Vercel deployment

```bash
# From repo root
vercel --prod

# Required env vars (set in Vercel dashboard or via Vault injection):
# MAPBOX_TOKEN          — from Vault yieldswarm/integrations/mapbox
# KAIRO_API_BASE        — https://api.kairo.x (Akash proxy)
# STRIPE_PUBLISHABLE_KEY — from Vault yieldswarm/runtime/payments
```

`vercel.json` routes `/kairo` → `kairo/frontend/index.html`.

### Inject Mapbox token at runtime

```html
<!-- In kairo/frontend/index.html, set before load: -->
<script>
  window.KAIRO_CONFIG = {
    mapboxToken: '<from Vault>',
    apiBase: 'https://api.kairo.x'
  };
</script>
```

Or use Vercel env substitution in a build step.

---

## Netlify alternative

```bash
cd kairo/frontend
netlify deploy --prod --dir=.
```

`netlify.toml` (create if needed):

```toml
[build]
  publish = "kairo/frontend"

[[redirects]]
  from = "/kairo/*"
  to = "/index.html"
  status = 200
```

---

## Local development

```bash
# Terminal 1 — Kairo API
cd kairo
pip install -r requirements.txt
python -m kairo.api.main

# Terminal 2 — static frontend
cd kairo/frontend
python -m http.server 5173

# Open http://localhost:5173
# Set window.KAIRO_CONFIG.apiBase = 'http://localhost:8787' in console
```

---

## Payment integration

Kairo fees flow through YieldSwarm payment rails (`src/app/payments/`):

| Fee | Rate | Destination |
|-----|------|-------------|
| Customer platform fee | 1% | YieldSwarm treasury |
| Driver pay | 2× base | Driver wallet (EVM/IoTeX) |
| DePIN earnings | 15% of fare | Akash worker pool |
| Mandelbrot bonus | variable | Emission router (50/30/15/5) |

Stripe webhooks: `src/app/api/webhooks/` — secrets from Vault `runtime/payments`.

---

## Akash deployment

Kairo API can run as an Akash sidecar alongside Odysseus workers:

```bash
# Uses shared worker SDL with KAIRO_PORT=8787
export KAIRO_HOST=0.0.0.0 KAIRO_PORT=8787
python -m kairo.api.main
```

Point `api.kairo.x` CNAME at the Akash stable proxy (see `DOMAINS.md` §5).

---

## Testing

```bash
pip install -r kairo/requirements.txt
python -m pytest kairo/tests/ -v
curl -sf http://localhost:8787/healthz
curl -X POST http://localhost:8787/api/telemetry/ingest \
  -H 'Content-Type: application/json' \
  -d '{"driver_id":"t1","evm_address":"0x'$(printf 'a%.0s' {1..40})'","latitude":39.74,"longitude":-104.99,"fare_usd":25}'
```

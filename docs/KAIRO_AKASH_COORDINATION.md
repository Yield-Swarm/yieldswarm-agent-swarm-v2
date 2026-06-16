# Kairo + Akash Parallel Tracks — Swarm Coordination

Coordinates **Track 1 (Kairo frontend)** and **Track 2 (live Akash deploy)** without file conflicts.

---

## Copy to Swarm Conductor

```
You are coordinating two parallel YieldSwarm tracks:

TRACK 1 — Kairo (cursor/kairo-akash-parallel-9c82)
  Owns: kairo/frontend/, backend/src/routes/kairo.js, backend/src/lib/kairoFare.js
  Do NOT touch: scripts/deploy-to-akash.sh, akash/, vault policies

TRACK 2 — Akash live deploy (cursor/akash-real-deploy-9c82 or main after merge)
  Owns: scripts/akash-preflight.sh, scripts/deploy-to-akash.sh, scripts/verify-akash-lease.sh
  Do NOT touch: kairo/frontend/index.html

MERGE ORDER: akash-real-deploy → kairo-akash-parallel → main

HUMAN GATES (stop agents):
  - Fund wallet ≥ 0.5 AKT
  - export VAULT_TOKEN=...
  - make akash-preflight → GO

AFTER AKASH LIVE:
  - source .run/akash-lease.env
  - Kairo /depin/status flips to live
  - Arena: /arena?workers=${AKASH_WORKER_URLS}

STATUS FORMAT:
[TRACK 1 Kairo] <done|blocked> — <note>
[TRACK 2 Akash] <done|blocked> — <note>
```

---

## Execution order

| Step | Human | Agent |
|------|-------|-------|
| 1 | Fund wallet + `VAULT_TOKEN` | Track 1: Kairo wiring (can start now) |
| 2 | — | Track 2: `make akash-preflight` |
| 3 | `make deploy-akash-europlots` | Track 2: verify + Arena URL |
| 4 | Test `/kairo-app/` on production API | Track 1: Vercel env vars |

---

## Track 1 — Kairo env (Vercel / Render)

| Variable | Where | Purpose |
|----------|-------|---------|
| `KAIRO_PUBLIC_API_BASE` | Integration backend | e.g. `https://api.yieldswarm.crypto/api/kairo` |
| `MAPBOX_TOKEN` or `VITE_MAPBOX_TOKEN` | Backend + Vercel | Map geocoding + live map |
| `KAIRO_API_BASE` | Backend (server) | Upstream Python API default `http://127.0.0.1:8091` |

Static app loads runtime config from **`/kairo-app/config.js`** when served by integration backend.

### Local dev

```bash
# Terminal 1 — Python Kairo API
python -m kairo.api.routes

# Terminal 2 — Integration backend
export MAPBOX_TOKEN=pk.eyJ...
cd backend && npm start

# Open
open http://localhost:8080/kairo-app/
```

### New API routes (integration `:8080`)

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/kairo/fare/quote` | Fare from distance/duration |
| `POST` | `/api/kairo/rides` | Create ride request |
| `GET` | `/api/kairo/rides/:id` | Ride status |
| `GET` | `/api/kairo/depin/status` | Akash worker connectivity |

---

## Track 2 — Akash (unchanged commands)

```bash
make akash-preflight
make deploy-akash-europlots
make akash-verify
source .run/akash-lease.env
```

See `docs/AKASH_DEPLOY.md` and `TODAY_EXECUTION_PLAN.md`.

---

## Definition of done (both tracks)

- [ ] `/kairo-app/` — quote → request ride → driver en route
- [ ] Mapbox map shows route line
- [ ] DePIN pill shows **Akash live** after deploy
- [ ] `make akash-verify` → GO
- [ ] Arena shows worker telemetry

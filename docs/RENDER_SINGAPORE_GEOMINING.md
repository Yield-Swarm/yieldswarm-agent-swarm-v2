# Render Singapore — DePIN Geomining Edge Engine

Lightweight telemetry collector for **ApolloNexusEngineInc** on Render Free tier
(**0.1 CPU, 512 MB RAM**). Service: `srv-d8sfuireo5us73efn3gg` →
`https://yieldswarm-agent-swarm-v2-mainnet.onrender.com`.

## Architecture

```
Client telemetry → POST /api/sync → validate + 202 ack
                         ↓ (non-blocking)
              in-memory batch queue (8 / 1.5s)
                         ↓
              Neon Serverless Postgres
```

The edge engine lives in `deploy/render/singapore/` (isolated from the root
Python Odysseus `Dockerfile`).

## One-time setup

### 1. Neon schema

```bash
psql "$DATABASE_URL" -f deploy/render/singapore/schema.sql
```

Or apply the consolidated migration:

```bash
psql "$DATABASE_URL" -f telemetry/neon/schema.sql
```

### 2. Render dashboard (srv-d8sfuireo5us73efn3gg)

| Setting | Value |
|---------|-------|
| **DATABASE_URL** | `postgres://[user]:[password]@[neon-host]/mainnet` |
| **Health check path** | `/healthz` |
| **Dockerfile path** | `deploy/render/singapore/Dockerfile` |
| **Docker context** | `deploy/render/singapore` |

Optional:

| Key | Default | Purpose |
|-----|---------|---------|
| `MONITOR_EMAIL` | `ethyswarm@proton.me` | Log sync events for operator inbox |
| `SYNC_BATCH_SIZE` | `8` | Max records per flush |
| `SYNC_FLUSH_MS` | `1500` | Batch interval (ms) |

### 3. Deploy

Push to `main` (or merge the PR). Render builds the multi-stage Node 18 Alpine
image with `--max-old-space-size=380 --expose-gc`.

```bash
git push origin main
```

## API

### `GET /healthz`

```json
{ "status": "HEALTHY", "instance": "helix-chain-node-sg", "queueDepth": 0 }
```

### `POST /api/sync`

```json
{
  "email": "ethyswarm@proton.me",
  "plan": "Lite",
  "currentBalance": 1000.0,
  "geomines": 5,
  "geodrops": 2,
  "surveys": 1,
  "spentGeoclaims": 0.0,
  "spentGeodrops": 0.0,
  "spentSweepstakes": 0.0
}
```

Response `202 Accepted`:

```json
{ "success": true, "queued": true, "queueDepth": 1 }
```

Counters (`geomines`, `geodrops`, `surveys`, spend fields) are **accumulated**
on conflict; `current_plan` and `current_balance` are overwritten.

## Local dev

```bash
cd deploy/render/singapore
npm ci
DATABASE_URL="postgres://..." npm start
```

## Tests

```bash
cd deploy/render/singapore && npm test
```

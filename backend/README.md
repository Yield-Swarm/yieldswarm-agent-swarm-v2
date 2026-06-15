# YieldSwarm Integration Backend

Integration layer that powers the **Arena dashboard** with live data fused from:

- **Akash workers** — network capacity + provider health (and owner-specific leases) via the Akash Console indexer API.
- **On-chain telemetry** (Solana RPC):
  - **Emission router** — $APN circulating supply, per-epoch/per-day emission, and route splits.
  - **Treasury splits** — treasury balance projected across the configured split policy.
  - **Agent leaderboard** — ranked by on-chain $APN holdings.

Every telemetry response carries a `source`/`live` flag. When an upstream is
unreachable or not yet configured, the adapter returns deterministic **fallback**
data clearly flagged as such, so the dashboard always renders and surfaces exactly
which connections are live vs. degraded.

## Run

```bash
cd backend
npm install
npm start          # serves API + frontends on http://localhost:8080
# npm run dev      # watch mode
# npm test         # unit tests (offline-safe)
```

Open:

- Portal hub: <http://localhost:8080/portal/>
- Arena dashboard: <http://localhost:8080/arena/>
- Aggregated API: <http://localhost:8080/api/arena/overview>

## API

| Method | Path | Description |
| ------ | ---- | ----------- |
| GET | `/api/health` | Upstream connectivity (Akash + Solana). |
| GET | `/api/arena/overview` | Aggregated payload for the dashboard (all sections + per-source connection health). |
| GET | `/api/akash/workers` | Akash network capacity + worker/lease telemetry. |
| GET | `/api/telemetry/emission-router` | Emission router telemetry. |
| GET | `/api/telemetry/treasury` | Treasury balance + splits. |
| GET | `/api/telemetry/leaderboard?limit=N` | Agent leaderboard (1–25). |

The server also resolves the previously-broken static links from the repo's HTML
(`/council/status`, `/marketplace`, `/sales`) and redirects `/` to the Portal.

## Configuration

All values are optional — the service boots with safe defaults. Set these in the
environment (or the repo `.env`) to turn fallback sections into live ones:

| Env var | Default | Purpose |
| ------- | ------- | ------- |
| `PORT` / `HOST` | `8080` / `0.0.0.0` | Listen address. |
| `SOLANA_RPC_URL` | mainnet-beta public RPC | On-chain reads. Use a dedicated RPC (e.g. Helius) to avoid `429` rate limits on heavier calls like the leaderboard. |
| `APN_MINT_ADDRESS` | `8JC3My2…Kpump` | $APN mint driving emission/leaderboard. |
| `EMISSION_ROUTER_ADDRESS` | — | Emission router account (adds live router balance). |
| `TREASURY_ADDRESS` | — | Treasury account; when set, splits are projected from the real balance. |
| `AKASH_CONSOLE_API` | `https://console-api.akash.network/v1` | Akash indexer base URL. |
| `AKASH_OWNER_ADDRESS` | — | `akash1…` owner; when set, active leases become concrete worker rows. |
| `SPLIT_*_BPS` | 20/35/25/20% | Treasury split policy in basis points. |
| `TELEMETRY_CACHE_TTL_MS` | `15000` | Cache window protecting upstreams from dashboard polling. |
| `UPSTREAM_TIMEOUT_MS` | `6000` | Per-request upstream timeout. |

### Connection notes

- **Akash workers** report *live* whenever the Console API is reachable (real
  network capacity flows immediately). Concrete per-worker rows require
  `AKASH_OWNER_ADDRESS`; otherwise a clearly-labeled sample fleet is shown.
- **Public Solana RPC** rate-limits heavy calls (`getTokenLargestAccounts`),
  which can push the **leaderboard** to fallback with an `HTTP 429` reason —
  configure a dedicated `SOLANA_RPC_URL` to keep it live.
- Public Cosmos REST nodes prune the Akash `market` module (HTTP 501 for lease
  queries), which is why the Console indexer API is used instead of raw LCD.

## Architecture

```
backend/src
├── server.js              Express app: API + static frontends + legacy links
├── config.js              Env-driven config with safe defaults
├── routes/api.js          API surface + /arena/overview aggregator (cached)
├── lib/
│   ├── http.js            fetch w/ timeout + JSON-RPC helper
│   └── cache.js           TTL cache w/ single-flight de-dup
└── adapters/
    ├── solana.js          Solana JSON-RPC reads (soft-fail, never throws up)
    ├── akash.js           Akash Console: network + owner leases (+ fallback)
    ├── emissionRouter.js  $APN supply → emission projection
    ├── treasury.js        Treasury balance → split policy
    └── leaderboard.js     Largest $APN holders → ranked agents (+ fallback)
```

Adapters never hard-fail the dashboard: each resolves independently in the
overview aggregator, so one slow/down upstream never blocks the others.

# God Prompts Ecosystem — Implementation Guide

Four production components implementing the multi-chain SDK fork pipeline, Grass-style node extension, gamified quest/lottery engine, and Matrix landing terminal.

## Prompt 1 — Multi-Chain SDK Synchronizer

| Asset | Path |
|-------|------|
| Manifest (22 repos) | `config/sdk-fork/manifest.json` |
| Routing descriptor | `config/sdk-fork/YIELDSWARM_ROUTING.json` |
| Sync script | `scripts/sdk/sync-fork-repos.sh` |

```bash
# Preview
./scripts/sdk/sync-fork-repos.sh --dry-run

# Execute (clones to workspace/sdk-forks/)
./scripts/sdk/sync-fork-repos.sh
```

Logs: `logs/sdk-sync/sync-*.log`

## Prompt 2 — Background Node Extension (MV3)

| File | Path |
|------|------|
| Manifest | `extensions/yieldswarm-node/manifest.json` |
| Service worker | `extensions/yieldswarm-node/background.js` |
| Popup UI | `extensions/yieldswarm-node/popup.html` + `popup.js` |

**Load in Chrome:** `chrome://extensions` → Developer mode → Load unpacked → `extensions/yieldswarm-node/`

## Prompt 3 — Quest & Lottery Engine

| Asset | Path |
|-------|------|
| PostgreSQL schema | `services/quests/schema.sql` |
| TypeScript engine | `services/quests/engine.ts` |
| VRF stub | `services/quests/vrf.ts` |
| REST API (alpha) | `backend/src/routes/quests.js` → `/api/quests/*` |

```bash
psql "$DATABASE_URL" -f services/quests/schema.sql
npm run test:unit -- services/quests/engine.test.ts
```

API:
- `GET /api/quests/definitions`
- `POST /api/quests/complete` `{ "accountId", "questId" }`
- `GET /api/quests/leaderboard`
- `POST /api/quests/lottery/draw` `{ "vrfSeed", "windowDate" }`

## Prompt 4 — Matrix Landing Terminal

| Asset | Path |
|-------|------|
| Self-contained page | `frontend/matrix/index.html` |

Open locally or deploy to Vercel static path `/matrix`.

## Architecture link

See [`ARCHITECTURE_FULL.md`](ARCHITECTURE_FULL.md) for full-stack diagram including DePIN node + quest flows.

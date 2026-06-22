# Launch Manifest — Correct npm / shell entrypoints

> `npm run run-all-onchain` was referenced in operator playbooks but was missing from
> root `package.json`. Use this table as the canonical launch map.

## Root `package.json` scripts

```bash
cat package.json | grep -A 30 '"scripts"'
```

| Script | Command | Purpose |
|--------|---------|---------|
| **`run-all-onchain`** | `bash scripts/run-all-onchain.sh` | **Helix + onchain unified boot** (Anchor → activate-helix → optional mining) |
| **`prod`** | `npm run build:all && npm start` | Next.js production (portal/arena) |
| **`prod:backend`** | `cd backend && npm start` | Integration API (`/api/helix`, `/api/nexus`, telemetry) |
| **`prod:helix`** | `bash scripts/activate-helix.sh` | Helix genesis only |
| **`prod:mining`** | `bash scripts/mining/start-all.sh` | Miner fleet (Bittensor, Grass, XMR, etc.) |
| **`deploy:stack`** | `bash deploy/deploy-full-stack.sh` | Full multi-phase deploy harness |
| **`start`** | `next start` | Next.js only — **not** the swarm orchestrator |

## What does NOT exist

| Wrong command | Use instead |
|---------------|-------------|
| `npm run run-all-onchain` (was missing) | Now wired — or `./scripts/run-all-onchain.sh` |
| `npm run prod` (was missing) | Now wired — or `npm run build:all && npm start` |
| `node src/orchestrator.js` | `node backend/src/server.js` or `cd backend && npm start` |
| `node src/index.js` | `node backend/src/server.js` |

## Mobile hotspot fleet (16 nodes)

Per node (Termux → use proot Ubuntu first):

```bash
# One-time per node
export GRASS_NODE_KEYS='["node-N-key"]'
SKIP_ANCHOR=1 START_MINING=1 npm run run-all-onchain
```

Or split concerns:

```bash
SKIP_ANCHOR=1 npm run run-all-onchain    # Helix + backend
npm run prod:mining                       # miners only
```

## Onchain workspace (`onchain/package.json`)

```bash
cd onchain
npm run build:sdk    # SDK workspace build
npm run build:app    # app workspace build
anchor build         # Solana programs (requires Anchor 0.30.1)
anchor test
```

## Quick verification

```bash
curl -s http://127.0.0.1:8080/api/helix/status | jq
curl -s http://127.0.0.1:8080/api/health
./scripts/mining/status.sh
```

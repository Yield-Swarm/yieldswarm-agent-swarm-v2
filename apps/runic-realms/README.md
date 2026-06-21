# Runic Realms

Telegram Mini App MMORPG — Diablo-style dungeons, RuneScape depth, WoW class fantasy. Every kill, mine, and dungeon clear generates **proof-of-compute** for the **Runic Chain** Swarm network. Players earn **$RUNE** from gameplay.

## Core loop (v0.1)

1. Open Telegram Mini App → pick class → enter procedural dungeon  
2. Tap monsters (red tiles) → skill rotation via WebSocket combat  
3. Tap nodes (cyan tiles) → mine runic gold  
4. Each action → `YSLR::COMPUTE::*` Sanscript job → Midas Swarm yield → $RUNE balance  
5. Clear floor → descend for higher rewards  

## Stack

| Layer | Path |
|-------|------|
| Telegram client | `apps/runic-realms/client` (Vite + React + TS) |
| Game server | `apps/runic-realms/server` (Node + WebSocket :8099) |
| $RUNE contract stub | `apps/runic-realms/contracts/RuneToken.sol` |
| Swarm bridge | Nexus · Helix · Shadow · Odysseus via YieldSwarm API |

## Run locally

```bash
# Terminal 1 — game server
cd apps/runic-realms/server && npm install && npm start

# Terminal 2 — Telegram client dev
cd apps/runic-realms/client && npm install && npm run dev
# → http://localhost:5175/runic/

# Or one-shot
chmod +x scripts/run-runic-realms.sh
./scripts/run-runic-realms.sh dev
```

## Production build

```bash
cd apps/runic-realms/client && npm run build
# Served at http://your-host:8080/runic/ via integration backend
```

## Telegram Bot setup

1. Create bot via [@BotFather](https://t.me/BotFather)  
2. Set Mini App URL to `https://your-domain/runic/`  
3. `export TELEGRAM_BOT_TOKEN=...` for initData HMAC validation  

## Classes

- **Runeblade** — melee burst  
- **Voidweaver** — arcane DPS  
- **Ironwarden** — tank  
- **Goldseeker** — Midas miner (bonus compute weight)  

## Swarm bridge

| Layer | Integration |
|-------|-------------|
| Apollo Nexus | `/api/nexus/status` |
| Helix | `/api/solenoid/pulse` + treasury |
| Shadow | `/api/shadow/arena/status` |
| **Alchemy** | Dynamic RPC across 18+ chains (`/api/chains/alchemy`) |
| **Plotra** | Deity agent registration + pixel avatar (`plotra.xyz`) |

### Alchemy chains

Set `ALCHEMY_API_KEY` — compute jobs anchor to a deterministic chain via `alchemyRouter.js`.

```bash
curl http://localhost:8099/api/chains/alchemy
```

### Plotra deity agents

On first connect, characters register as Plotra agents and paint a class-motif genesis avatar.

```bash
curl http://localhost:8099/api/agent/plotra/YOUR_TELEGRAM_ID
```

Set `PLOTRA_SIMULATE=1` for offline dev without calling plotra.xyz.

## Roadmap (not yet in v0.1)

Guilds · PvP arenas · world bosses · on-chain loot rarity · $RUNE staking/governance

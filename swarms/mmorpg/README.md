# SWARM 4: MMORPG Engine

**Status:** genesis (scaffolded)  
**Schema:** `schemas/helical/mmorpg.v1.json`

## Design pillars

| Pillar | Inspiration | Implementation track |
|--------|-------------|---------------------|
| Social economics | Destiny fireteams/clans | `players[].social` — reputation, bounty credits |
| Skill progression | RuneScape 1–99 matrix | `players[].skills` — driving, efficiency, exploration |
| Physical bridge | SWARM 1 Tesla telemetry | `physicalBridge` + vehicle `mmorpgBridge` events |

## Helical ingest

Headless Linux terminals at the Carrizozo edge cluster read `.data/physical-core/latest.json` and map vehicle kinematics to skill XP deltas.

## Entrypoint (planned)

```bash
python3 -m swarms.mmorpg.engines.world_sync
```

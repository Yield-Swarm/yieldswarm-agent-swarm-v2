# Four-Swarm Mainnet Lifecycle

Copy `.env.swarm.example` → `.env.swarm` and fill secrets.

```bash
cp .env.swarm.example .env.swarm
docker compose up -d redis postgres
docker compose up swarm-coordinator swarm-physical-core swarm-mining-pools swarm-mesh-engine
```

Or run locally:

```bash
pip install -r requirements-swarm.txt
PYTHONPATH=. python3 -m swarms.helical.coordinator
make four-swarm-test
```

## Swarms

| # | ID | Directory |
|---|-----|-----------|
| 1 | `physical-core` | `swarms/physical_core/` |
| 2 | `mining-pools` | `swarms/mining_pools/` |
| 3 | `cosmic-onboarding` | `swarms/cosmic_onboarding/` |
| 4 | `mesh-engine` | `swarms/mesh_engine/` |

IPC: `swarms/helical/ipc_bridge.py`

See `docs/FOUR_SWARM_HELICAL_ARCHITECTURE.md`.

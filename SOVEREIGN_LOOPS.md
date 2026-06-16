# Sovereign Autonomous Loops

Production wiring for the Iteration 100 sovereign core: self-healing Akash
leases, dynamic treasury rebalancing, and unified dashboard persistence.

## Architecture

```
deploy/runtime/swarm_runner.py
        │
        ▼
services/sovereign_runtime.py  ◀── agents/chainlink-vault-manager.py
        │
        ├── services/live_akash_heal.py  →  deploy/akash/auto-heal.sh --once
        ├── services/live_treasury.py    →  Great Delta 50/30/15/5 overlay
        └── iteration-100/sovereign_core.py  (single tick)
                ├── self_healing_leases.py
                ├── treasury_rebalancer.py
                ├── agent_mutation.py
                └── delta_grid_marketplace.py
        │
        ▼
dashboard/state.json  +  .run/akash-heal.json  +  .run/treasury-overlay.json
```

## Running

### Swarm sovereign loop (production)

```bash
export SOVEREIGN_LOOP_INTERVAL=900
python3 deploy/runtime/swarm_runner.py
```

Or use the supervisor:

```bash
bash deploy/scripts/start-sovereign-loops.sh start
```

This starts:

- `swarm_runner.py` — full sovereign cycle each tick
- `auto-heal.sh` — continuous Akash lease healing (when `.run/akash-lease.env` exists)

### Single cycle (CI / debugging)

```bash
SOVEREIGN_ONESHOT=1 python3 deploy/runtime/swarm_runner.py
# or
python3 services/sovereign_runtime.py
```

### Simulation backtest

```bash
cd iteration-100
python3 run.py --ticks 500
```

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `SOVEREIGN_STATE_PATH` | `dashboard/state.json` | Persisted sovereign snapshot |
| `SOVEREIGN_LIVE_HEAL` | `1` | Run `auto-heal.sh --once` before each tick |
| `SOVEREIGN_USE_RUNTIME` | `1` | `iteration_100_sovereign_loops.py` delegates to runtime |
| `AKASH_LIVE` | `0` | Merge real `akash query market lease list` into fleet |
| `AKASH_LEASE_ENV` | `.run/akash-lease.env` | Live lease metadata for healing |
| `YIELDSWARM_BACKEND_URL` | — | Fetch live treasury splits from `/api/telemetry/treasury` |
| `SOL_USD_PRICE` | `145` | Convert on-chain SOL treasury to USD |

## Self-healing Akash leases

Each sovereign cycle:

1. **Shell auto-heal** — tops up escrow, re-sends manifest on health failure, recreates closed leases.
2. **Worker probes** — `services/akash_worker_sync.py` hits `/healthz` and marks fleet workers `degraded`.
3. **Simulation heal** — `self_healing_leases.step()` redeploys, migrates, tops up credits, retires losers.

Heal actions are logged in `state.json` events and `.run/akash-heal.json`.

## Dynamic treasury rebalancing

Two layers run each cycle:

1. **Policy rebalance** (`live_treasury.py`) — enforces Great Delta 50/30/15/5 bucket weights when drift exceeds the band.
2. **APY mandate** (`treasury_rebalancer.py`) — when blended APY falls below 30%, capital moves from low-yield liquid venues to the best risk-adjusted sink.

Treasury data sources (in order):

1. `YIELDSWARM_BACKEND_URL/api/telemetry/treasury` (live Solana RPC)
2. `.run/treasury-overlay.json` (cached)
3. Deterministic fallback ($1.85M)

## Dashboard

- `dashboard/state.json` — canonical sovereign snapshot (read by `backend/src/adapters/sovereign.js`)
- `dashboard/final-monitoring-dashboard-5m.md` — per-cycle markdown summary
- `dashboard/sovereign-dashboard.html` — static viewer (`python3 -m http.server` in `dashboard/`)

## Tests

```bash
python3 -m unittest tests.test_sovereign_runtime -v
```

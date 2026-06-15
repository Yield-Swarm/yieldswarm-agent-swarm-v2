# Iteration 100 — Sovereign Self-Governed Core

The autonomous core loop that drives the YieldSwarm treasury toward a
**$5,000,000 vault** with no human in the loop. It is dependency-free
(Python 3 standard library only) and runs end-to-end as a deterministic-but-
evolving simulation, falling back to live Akash queries when keys are present.

```
                 ┌─────────────────────────────────────────────┐
   Akash         │            sovereign_core.tick()             │
   telemetry ───▶│  1. akash_feed.refresh   (real perf data)    │
                 │  2. agent_mutation.step  (evolve genomes)    │
                 │  3. self_healing.step    (redeploy/heal)     │
                 │  4. delta_grid.step      (compute + talent)  │
                 │  5. treasury.step        (defend APY mandate)│
                 │  6. reinvest             (compound surplus)  │
                 └──────────────────┬──────────────────────────┘
                                    ▼
                        dashboard/state.json  →  sovereign-dashboard.html
```

## Core loop files

| File | Responsibility |
|------|----------------|
| `sovereign_core.py` | Orchestrator: owns `SovereignState`, runs the tick loop, reinvests surplus, persists the dashboard snapshot. |
| `agent_mutation.py` | Autonomous agent mutation. Steady-state genetic algorithm whose fitness is measured from the **realised ROI** of the Akash workers each agent drives. |
| `self_healing_leases.py` | Self-healing leases: redeploys failed providers, migrates degraded ones, tops up prepaid AKT runway, retires chronic losers. |
| `treasury_rebalancer.py` | Dynamic treasury rebalancing. When blended APY drops below the 30% mandate, capital is moved from low-yield liquid venues into the best risk-adjusted venue. |
| `delta_grid_marketplace.py` | The Great Delta Grid: a two-sided marketplace routing external **compute** demand to idle workers and **talent** demand to high-fitness agents, taking an 18% commission. |
| `core/state.py` | Shared state, domain models, telemetry, and JSON persistence for the dashboard. |
| `core/akash_feed.py` | Real-or-simulated Akash worker performance feed (clean prepaid-opex accounting). |

## Run it

```bash
cd iteration-100
python3 run.py --ticks 2200          # one tick == one operating day
```

This writes `../dashboard/state.json`. Open the dashboard:

```bash
cd ../dashboard
python3 -m http.server 8080          # then visit http://localhost:8080/sovereign-dashboard.html
```

Useful flags: `--seed-workers`, `--seed-agents`, `--seed-treasury`,
`--seed-vault`, `--target-apy`, `--interval` (seconds/tick for a live daemon),
`--quiet`.

## Going live against real Akash

Set `AKASH_LIVE=1` (and have the `akash` CLI authenticated) so
`core/akash_feed.py` merges real `market lease list` deployments into the
fleet. All other subsystems are agnostic to whether the telemetry is live or
simulated.

## Economic model (accounting)

- **Lease credits** are a balance-sheet asset (prepaid AKT). Provisioning and
  top-ups move cash from the vault into credits (net-worth neutral).
- **Gross lease revenue** books into the operating vault each day; **opex** is
  consumed from prepaid credits. The only real losses are provider failures
  (lost remaining credits), redeploy/migrate fees, and unprofitable retirement.
- **Net worth** = vault + treasury + fleet credits, tracked against the $5M
  target.

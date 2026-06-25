# Four-Swarm Helical Architecture

**Master Architect initialization** — parallel development tracks for YieldSwarm mainnet.

## Conceptual evolution

| Era | Focus | Pivot |
|-----|-------|-------|
| v1 AgentSwarm | 10,080 charting agents + Great Delta treasury | Scaffold → live GPU |
| Trident / Layer-35 | Akash + DePIN + marketplace rails | Infra tracks ≠ domain swarms |
| **Helical v2 (now)** | 4 sovereign swarms + Carrizozo physical anchor | Unified JSON schemas + epoch bus |

### Scaling targets

- **Physical:** 10-acre NM site, 27 kW solar, 30 ASICs, 4 Tesla vehicles, dual Starlink
- **Compute:** Akash GPU workers + Mac Mini edge orchestration
- **Economic:** 50/30/15/5 treasury invariant across all swarm yield paths
- **Latency:** ≤80 ms p95 orchestration; 420 s helical heartbeat

## Four parallel tracks

```
                    ┌─────────────────────────────────────┐
                    │     Helical Bus (420s epoch)        │
                    │  dashboard/helical-state.json       │
                    └─────────────────────────────────────┘
           phase 0          phase 1         phase 2        phase 3
              │                │               │              │
    ┌─────────▼────────┐ ┌─────▼─────┐ ┌──────▼──────┐ ┌────▼─────┐
    │ SWARM 1          │ │ SWARM 2   │ │ SWARM 3     │ │ SWARM 4  │
    │ Physical Core    │ │ Mining    │ │ Marketplace │ │ MMORPG   │
    │ Carrizozo edge   │ │ Pools     │ │ Web3        │ │ Engine   │
    └─────────┬────────┘ └─────┬─────┘ └──────┬──────┘ └────┬─────┘
              │                │               │              │
              └────────────────┴───────────────┴──────────────┘
                         schemas/helical/*.v1.json
```

| Swarm | Directory | Schema | Maturity |
|-------|-----------|--------|----------|
| 1 Physical Core | `swarms/physical_core/` | `physical-core.v1.json` | **scaffolded** (drivers live) |
| 2 Mining Pools | `swarms/mining_pools/` | `mining-pools.v1.json` | genesis |
| 3 Marketplace | `swarms/marketplace/` | `marketplace.v1.json` | genesis |
| 4 MMORPG | `swarms/mmorpg/` | `mmorpg.v1.json` | genesis |

## Shared contracts

All inter-swarm messages use the helical envelope:

```json
{
  "schemaVersion": "helical-envelope/v1",
  "swarmId": "physical-core",
  "epoch": 42,
  "phase": 2,
  "messageId": "...",
  "payload": { }
}
```

State contract: `schemas/helical/state-contract.v1.json` → `dashboard/helical-state.json`

## SWARM 1 detail (Sovereign Data Ranch)

See `swarms/physical_core/README.md`.

- **Solar:** 27 kW Tesla array production + battery SoC
- **Connectivity:** Dual Starlink active-standby failover
- **ASICs:** 30× Antminer Z15 Pro Equihash monitoring matrix
- **Vehicles:** Tesla Fleet API → kinematics → `mmorpgBridge` skill events
- **Edge:** Mac Mini orchestrator + Pi/NUC cluster headless broadcast

## Operations

```bash
# SWARM 1 monitoring matrix
make physical-core-monitor

# Single helical heartbeat (rotates active swarm phase)
make helical-heartbeat
```

## Relationship to Helix Chain

`dashboard/helix-state.json` tracks **infra readiness** (domains, akash, terraform, vault).  
`dashboard/helical-state.json` tracks **domain swarms** (physical, mining, marketplace, mmorpg).

Both layers must activate for full mainnet sovereignty.

## Non-negotiable invariants

1. Treasury split 50/30/15/5 on every yield attribution path
2. No secrets in repo — Tesla, Starlink, pool credentials via Vault/env
3. Helical receipts retained (last 100) for audit trail

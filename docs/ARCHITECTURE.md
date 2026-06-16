# YieldSwarm Architecture v2.2 — 30-Day Harvest + Cross-Chain

Canonical architecture: **async cloud scheduler**, **Sovereign Consensus**, **Great Delta**, **cross-chain execution**.

---

## System overview

```mermaid
flowchart TB
  subgraph CentralBrain["Central Brain — Cron + Async"]
    CS[CloudScheduler 10min]
    DE[Decision Engine]
    AQ[Async Job Queue]
    UT[Unified Telemetry]
    CS --> DE --> AQ
    AQ --> UT
  end

  subgraph Sovereign["Sovereign Consensus 900s"]
    SR[swarm_runner.py]
    CSA[cloud_scheduler_agent]
    CC[cross_chain_executor]
    I100[sovereign_loops]
    SR --> CSA
    SR --> CC
    SR --> I100
  end

  CSA --> CS

  subgraph Providers["Multi-Cloud Providers"]
    AKASH[Akash RTX 3090]
    VAST[Vast.io]
    RUNPOD[RunPod]
    AZURE[Azure]
    GCP[GCP]
    AWS[AWS]
    ALI[Alibaba]
  end

  CS --> AKASH
  CS --> VAST
  CS --> RUNPOD
  CS --> AZURE
  CS --> GCP
  CS --> AWS
  CS --> ALI

  subgraph Revenue["Revenue Streams"]
    BT[Bittensor TAO]
    INF[GPU Inference]
    DEPIN[Grass DePIN]
    XCHAIN[Cross-Chain DeFi]
  end

  AKASH --> BT
  AKASH --> INF
  VAST --> INF
  AZURE --> DEPIN
  CC --> XCHAIN

  subgraph Treasury["Great Delta 50/30/15/5"]
    GD[route_revenue]
    ROUTER[EmissionRouter.sol]
    GD --> ROUTER
  end

  BT --> GD
  INF --> GD
  DEPIN --> GD
  XCHAIN --> GD
  UT --> GD

  subgraph Secrets["HashiCorp Vault"]
    VAULT[KV runtime + rpc]
  end

  Providers --> VAULT

  subgraph Observability
    API["/api/* telemetry"]
    ARENA[Arena Dashboard]
  end

  UT --> API --> ARENA
```

---

## Layer map

| Layer | Components | Cadence |
|-------|------------|---------|
| L0 Gospel | `gospel.py` — harvest phase + 50/30/15/5 | invariant |
| L0.5 Scheduler | `cloud_scheduler/` + `async_jobs/` | **10 min cron** |
| L1 Sovereign | `swarm_runner.py` + agents | **900s tick** |
| L2 Cross-chain | `services/cross_chain/` | per sovereign tick |
| L3 Treasury | Great Delta routing | on revenue event |
| L4 Compute | 7 cloud providers | async jobs |
| L5 Telemetry | `.run/cloud-telemetry.json` | continuous |

---

## Async data flow

```
Cron (10m) → CloudScheduler.tick()
  → DecisionEngine.decide() — ROI + week phase
  → AsyncJobQueue.enqueue() — bittensor, training, grass
  → process_pending() — launch with retry + migration
  → UnifiedTelemetry.ingest_worker()
  → Great Delta rebalance input

Sovereign (900s) → cloud_scheduler_agent.tick() — sync with cron state
                 → cross_chain_executor — DeFi revenue
                 → iteration_100_sovereign_loops — treasury policy
```

---

## Related docs

- `docs/MULTI_CLOUD_30DAY_PLAN.md` — 30-day execution playbook
- `docs/CROSS_CHAIN_EXECUTION.md` — Uniswap V4, Solana, dYdX, PoW
- `config/cloud_scheduler/schedule.yaml` — scheduler config
- `crons/cloud-scheduler.cron.example` — crontab install

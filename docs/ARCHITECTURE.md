# YieldSwarm Architecture v2.1 — Cross-Chain Execution Layer

Canonical architecture including **God Prompt P** cross-chain expansion.

---

## System overview

```mermaid
flowchart TB
  subgraph Sovereign["Sovereign Consensus"]
    SR[swarm_runner.py]
    CC[cross_chain_executor.py]
    I100[iteration_100_sovereign_loops]
    SR --> CC
    SR --> I100
  end

  subgraph Execution["Cross-Chain Execution"]
    EX[CrossChainExecutor]
    U[Uniswap V4 Hooks]
    SOL[Jupiter / Orca / Raydium]
    DY[dYdX Perps]
    POW[Altcoin PoW]
    EX --> U
    EX --> SOL
    EX --> DY
    EX --> POW
  end

  subgraph Treasury["Great Delta 50/30/15/5"]
    GD[route_revenue_to_treasury]
    ROUTER[GreatDeltaEmissionRouter.sol]
    GD --> ROUTER
  end

  subgraph Infra["Compute + Secrets"]
    AKASH[Akash GPU]
    VAULT[HashiCorp Vault]
    MC[Multi-Cloud Burst]
  end

  CC --> EX
  EX --> GD
  POW --> AKASH
  EX --> VAULT
  AKASH --> MC

  subgraph Observability
    API["/api/cross-chain/*"]
    ARENA[Arena Dashboard]
  end

  EX --> API --> ARENA
```

---

## Layer map

| Layer | Components | Status |
|-------|------------|--------|
| L0 Gospel | `agents/governance/gospel.py` | 50/30/15/5 invariants |
| L1 Sovereign | `swarm_runner.py`, `cross_chain_executor.py` | Live supervisor |
| L2 Execution | `services/cross_chain/` | Scaffold → production |
| L3 Treasury | `great_delta.py`, emission router | Split math live; on-chain pending |
| L4 Compute | Akash, Vast, RunPod, Azure, GCP | Multi-cloud plan |
| L5 Observability | Backend adapters, Arena | `/api/cross-chain/overview` |

---

## Revenue flow

All cross-chain gross revenue **must** pass through Great Delta before settlement:

```
Strategy PnL → route_revenue_to_treasury() → 50/30/15/5 buckets → EmissionRouter (on-chain)
```

---

## Related docs

- `docs/CROSS_CHAIN_EXECUTION.md` — full God Prompt P spec
- `docs/YieldSwarm_v1_v2_Trident_Layer35_Blueprint.md` — Layer 0–6 blueprint
- `HELIX-EXECUTION.md` — Helix activation tracks
- `config/cross_chain/strategies.yaml` — strategy registry

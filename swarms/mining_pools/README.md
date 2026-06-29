# SWARM 2: Multi-Mining Token Pools

**Status:** genesis (scaffolded)  
**Schema:** `schemas/helical/mining-pools.v1.json`

## Scope

- Route Equihash hashrate from SWARM 1 Z15 fleet across multiple pool endpoints
- Attribute yield through Great Delta 50/30/15/5 treasury split
- Emit `physicalCoreRef` helical receipts back to physical-core epoch

## Entrypoint (planned)

```bash
python3 -m swarms.mining_pools.engines.pool_router
```

## Helical ingest

Consumes `physical-core` envelope `payload.asics.aggregateHashrateGh` and produces `mining-pools/v1` state for SWARM 3 marketplace pricing.

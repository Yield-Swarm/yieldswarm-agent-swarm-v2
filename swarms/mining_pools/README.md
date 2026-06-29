# SWARM 2: Multi-Mining Token Pools

**Status:** live (PoWUoI six-coin launch)  
**Schema:** `schemas/helical/mining-pools.v1.json`

## Scope

- Launch all **six PoWUoI coins** on Akash: **PRL** (YieldSwarm-native), **KRX**, **ZANO**, **QTC**, **IRON**, **TON**
- Route Equihash hashrate from SWARM 1 Z15 fleet (ZEC ranch extension)
- Attribute yield through Great Delta 50/30/15/5 treasury split
- Emit `physicalCoreRef` helical receipts back to physical-core epoch

## Entrypoint

```bash
# Dry-run (default): write configs + helical state
./scripts/mining/launch-pouw-pools.sh launch

# Live local supervisors
MINING_DRY_RUN=0 ./scripts/mining/launch-pouw-pools.sh launch --live

# Akash deploy (Vault + funded wallet required)
./scripts/mining/launch-pouw-pools.sh launch --akash --live
```

Registry: `config/mining/pouw-coins.json`

## Helical ingest

Consumes `physical-core` envelope `payload.asics.aggregateHashrateGh` and produces `mining-pools/v1` state for SWARM 3 marketplace pricing.

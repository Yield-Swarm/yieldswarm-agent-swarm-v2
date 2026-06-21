# YieldSwarm Indexer — Geyser + PostgreSQL Spec (GP7)

## Overview

The indexer ingests on-chain events from `cross_chain`, `swarm_ops`, `coordinator`, and `yield_vault` programs into PostgreSQL for the dashboard and analytics.

## Data sources

| Program | Events / accounts | Table |
|---------|-------------------|-------|
| `cross_chain` | `EventLog`, `CrossChainYieldReceived`, `RemoteHarvestTriggered` | `cross_chain_harvests` |
| `swarm_ops` | `AgentPermissionRegistry`, strategy proposals | `agent_yield_events` |
| `coordinator` | `ShardVault`, `VaultCoordinator` | `shard_snapshots` (future) |
| `yield_vault` | deposit/withdraw/harvest | `agent_yield_events` |

## Geyser plugin filter

```json
{
  "accounts": {
    "cross_chain": ["bridge_state"],
    "coordinator": ["shard_vault", "vault_coordinator"],
    "swarm_ops": ["agent_registry"]
  },
  "transactions": {
    "vote": false,
    "failed": false,
    "account_include": [
      "XChn1111111111111111111111111111111111111",
      "Swrm1111111111111111111111111111111111111",
      "Cord1111111111111111111111111111111111111"
    ]
  }
}
```

## EventLog decoding

`EventLog.kind`:
- `1` — harvest trigger (`EVENT_KIND_HARVEST_TRIGGER`)
- `2` — yield received (`EVENT_KIND_YIELD_RECEIVED`)

Map `chain_id` to Helix (`0x484c58`) or Solana (`0`) per `sdk/src/cross-chain/client.ts`.

## Ingestion pipeline

1. Geyser gRPC stream → Rust/Node consumer
2. Parse Anchor events via discriminator + Borsh layout
3. Upsert into `schema.sql` tables (idempotent on `signature`)
4. Expose REST `/api/indexer/yields` for dashboard (optional Instance B extension)

## Schema

Apply with:

```bash
psql "$DATABASE_URL" -f indexer/schema.sql
```

## Operational notes

- Poll fallback: `BridgeListener` in SDK (15s interval) until Geyser is live
- Retention: 90 days hot, archive to object storage
- PII: store pubkeys only, never private keys

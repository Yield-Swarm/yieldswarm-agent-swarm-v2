# ValhallA Indexer — Geyser Plugin & RPC Log Listener Spec

Indexer for YieldSwarm Instance B on-chain programs: `cross_chain`, `swarm_ops`, `shard_coordinator`.

## Architecture

```
Solana Validator / RPC
        │
        ├── Geyser plugin (primary) ──► Kafka / Redis stream
        │                                      │
        └── RPC logSubscribe (fallback) ───────┤
                                               ▼
                                    Indexer Worker (Node/Rust)
                                               │
                                               ▼
                              PostgreSQL (telemetry/postgres/valhalla_indexer.sql)
                                               │
                                               ▼
                              ValhallA Dashboard (app/dashboard)
```

## Subscribed Programs

| Program ID | Events / Accounts |
|------------|-------------------|
| `CrossChn1111111111111111111111111111111111` | `EventLog`, `TreasuryRouteEvent`, `TreasuryRegistry`, `MiningRoot` |
| `SwarmOps111111111111111111111111111111111` | `StrategyProposal`, `AgentPermissionRegistry` |
| `ShardCrd111111111111111111111111111111111` | `ShardEventLog`, `ShardSweepEvent`, `ShardVault`, `CoordinatorState` |

## Geyser Plugin Filter Config

```json
{
  "accounts": {
    "cross_chain": {
      "owner": ["CrossChn1111111111111111111111111111111111"],
      "filters": [{ "memcmp": { "offset": 0, "bytes": "base58_discriminator" } }]
    },
    "swarm_ops": {
      "owner": ["SwarmOps111111111111111111111111111111111"]
    },
    "shard_coordinator": {
      "owner": ["ShardCrd111111111111111111111111111111111"]
    }
  },
  "transactions": {
    "vote": false,
    "failed": false,
    "account_include": [
      "CrossChn1111111111111111111111111111111111",
      "SwarmOps111111111111111111111111111111111",
      "ShardCrd111111111111111111111111111111111"
    ]
  }
}
```

## Event Parsing

### cross_chain::EventLog

| Field | DB Column |
|-------|-----------|
| `kind` | `cross_chain_events.kind` |
| `origin_chain_id` | `cross_chain_events.origin_chain_id` |
| `asset_amount` | `cross_chain_events.asset_amount` |
| `agent` | `cross_chain_events.agent_pubkey` |
| `bridge_message_hash` | `cross_chain_events.bridge_message_hash` |

Kinds: `1` = harvest trigger, `2` = yield received.

### swarm_ops proposals

On `propose_strategy` / `approve_strategy` account updates, upsert `strategy_proposals` and roll daily spend into `agent_performance_daily`.

### shard_coordinator::ShardEventLog

Update `shard_vaults.liquidity`, `efficiency_bps`, and `updated_at` on deposit/rebalance events.

## RPC Fallback Listener

```typescript
connection.onLogs(
  CROSS_CHAIN_PROGRAM_ID,
  (logs) => parser.ingestLogs(logs),
  'confirmed'
);
```

Parse Anchor event discriminators from `Program data:` log lines.

## APY & Win Rate Aggregation

1. **APY** — rolling 24h yield from `cross_chain_events` where `kind = 2`, annualized against `shard_vaults.liquidity`.
2. **Win rate** — increment `win_count` when bridged yield exceeds proposed `spend_amount`; else `loss_count`.
3. Refresh `mv_agent_win_rates` every 5 minutes via `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

## Yield Route Feeds (off-chain)

Poll Kamino, Drift, and JitoSOL public APIs every 60s; insert into `yield_routes` for dashboard routing panel.

## Environment

| Variable | Purpose |
|----------|---------|
| `SOLANA_RPC_URL` | WebSocket + HTTP endpoint |
| `DATABASE_URL` | PostgreSQL connection |
| `INDEXER_PROGRAM_IDS` | Comma-separated program pubkeys |
| `YIELD_ROUTE_POLL_MS` | Default `60000` |

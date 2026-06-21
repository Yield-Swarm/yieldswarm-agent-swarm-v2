# YieldSwarm On-Chain Monorepo (Anchor 0.30+)

Solana programs for the dual-instance God Prompt pipeline. See `docs/DUAL_INSTANCE_GOD_PROMPTS.md`.

## Layout

```
onchain/
  programs/     yield_vault, bonding_curve, cross_chain, swarm_ops, coordinator, security
  sdk/          TypeScript program IDs + PDA seeds (Instance B extends)
  tests/        anchor test suites
  app/          GP8 dashboard (Instance B)
  indexer/      GP7 PostgreSQL schema
  scripts/      deploy.sh
```

## Quick start

```bash
cd onchain
anchor build
npm install
npm run build:sdk
npm run dev:app          # http://localhost:3000
psql "$DATABASE_URL" -f indexer/schema.sql
anchor test
./scripts/deploy.sh devnet
```

## Instance B deliverables (GP5–8)

| Prompt | Location | Key components |
|--------|----------|----------------|
| 5 Cross-Chain | `programs/cross_chain/`, `sdk/src/cross-chain/` | `trigger_remote_harvest`, `receive_cross_chain_yield`, `EventLog`, `CrossChainClient`, `useCrossChainBridge` |
| 6 Swarm Ops | `programs/swarm_ops/` | 521-agent registry, `propose_strategy` / `approve_strategy`, daily spend limits, `multisig.rs` |
| 7 Sharded Vaults | `programs/coordinator/`, `indexer/` | `ShardVault` / `VaultCoordinator` PDAs, `rebalance_shards`, `schema.sql`, `INDEXER_SPEC.md` |
| 8 Dashboard | `app/` | Wallet adapter, `useYieldVault`, routing panel, deposit/withdraw/claim UI |

## Instance ownership

| Instance | Programs |
|----------|----------|
| A | yield_vault, bonding_curve, security |
| B | cross_chain, swarm_ops, coordinator |

Treasury split invariant: **50/30/15/5** Great Delta (see `backend/src/lib/great-delta-split.js`).

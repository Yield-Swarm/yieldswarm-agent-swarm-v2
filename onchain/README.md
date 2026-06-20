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
anchor test
./scripts/deploy.sh devnet
```

## Instance ownership

| Instance | Programs |
|----------|----------|
| A | yield_vault, bonding_curve, security |
| B | cross_chain, swarm_ops, coordinator |

Treasury split invariant: **50/30/15/5** Great Delta (see `backend/src/lib/great-delta-split.js`).

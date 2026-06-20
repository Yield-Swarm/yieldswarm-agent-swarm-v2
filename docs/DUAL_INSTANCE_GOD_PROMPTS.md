# Dual-Instance God Prompts — 55-Agent Swarm Coordination

> **Instance A:** Core on-chain & economics (`onchain/programs/yield_vault`, `bonding_curve`, RBAC, CI)  
> **Instance B:** Automation, swarm ops & interfaces (`cross_chain`, `swarm_ops`, `sdk/`, `app/`, indexer)

## Prompt mapping (16 → 8 God Prompts)

| God Prompt | Instance | Source prompts | Owns (paths) |
|------------|----------|----------------|--------------|
| **GP1** Yield Core | A | 1, 7 | `onchain/programs/yield_vault/` |
| **GP2** Bonding Curve | A | 3, 4 | `onchain/programs/bonding_curve/` |
| **GP3** RBAC & Security | A | 8, 10 | `onchain/programs/security/` + hardening PRs to A programs |
| **GP4** Monorepo & CI | A | 16 | `onchain/Anchor.toml`, `Cargo.toml`, `.github/workflows/anchor-ci.yml` |
| **GP5** Cross-Chain | B | 2, 13 | `onchain/programs/cross_chain/` + `onchain/sdk/bridge/` |
| **GP6** Swarm & Multisig | B | 5, 6 | `onchain/programs/swarm_ops/` |
| **GP7** Sharding & Indexer | B | 14, 15 | `onchain/programs/coordinator/` + `onchain/indexer/` |
| **GP8** Dashboard & Router UI | B | 11, 12 | `onchain/app/` (reads programs via `onchain/sdk/`) |

## Architectural invariants (both instances)

1. **Treasury split** — canonical Great Delta: **50% core / 30% growth / 15% insurance / 5% ops** (maps to `GreatDeltaEmissionRouter.sol` and `backend/src/lib/great-delta-split.js`). GP1 draft ratios must sum to 100% before merge.
2. **$APN mint** — `APN_MINT_ADDRESS` in `.env.example`; bonding curve references config, never hardcodes mints.
3. **PDA seeds** — documented in `onchain/docs/PDA_REGISTRY.md`; no overlapping seeds across programs.
4. **Program IDs** — from `anchor keys list` after first build; committed in `onchain/Anchor.toml` per cluster.
5. **EVM router** — `contracts/GreatDeltaEmissionRouter.sol` is the EVM track; Solana programs are parallel.

## Parallel sync pipeline

```
WEEK 0 — Foundation
  [A] GP4: scaffold onchain/ monorepo + CI          → merge PR #1
  [B] WAIT for onchain/Anchor.toml + program stubs

WEEK 1 — Core programs (parallel)
  [A] GP1 + GP2: yield_vault + bonding_curve        → PR #2a
  [B] GP5 + GP6: cross_chain + swarm_ops            → PR #2b (rebase on #1)

WEEK 2 — Hardening + scale (parallel)
  [A] GP3: RBAC + security tests                    → PR #3a
  [B] GP7: coordinator shards + indexer schema      → PR #3b

WEEK 3 — Interface
  [A] anchor build && anchor test && program IDs    → gate
  [B] GP8: onchain/app dashboard + SDK hooks        → PR #4
```

## Branch naming

| Instance | Prefix | Example |
|----------|--------|---------|
| A | `cursor/onchain-a-*-9c82` | `cursor/onchain-a-yield-vault-9c82` |
| B | `cursor/onchain-b-*-9c82` | `cursor/onchain-b-cross-chain-9c82` |

**Rule:** Do not edit the other instance's owned paths in the same PR.

## Instance preambles (paste into Cursor)

**Instance A:**
```
Own: onchain/programs/yield_vault, bonding_curve, security, Anchor.toml, anchor-ci.
Do NOT edit: cross_chain, swarm_ops, coordinator, onchain/app, sdk/bridge.
Great Delta 50/30/15/5. Anchor 0.30+.
```

**Instance B:**
```
Own: cross_chain, swarm_ops, coordinator, onchain/sdk, onchain/app, onchain/indexer.
Do NOT edit: yield_vault, bonding_curve, security core.
Use program IDs from Anchor.toml. Wallet patterns: frontend/src/wallet/.
```

## Commands

```bash
cd onchain && anchor build && anchor test
./onchain/scripts/deploy.sh devnet
```

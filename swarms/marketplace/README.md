# SWARM 3: Cross-Chain Web3 Marketplace

**Status:** genesis (scaffolded)  
**Schema:** `schemas/helical/marketplace.v1.json`

## Scope

- Z15 Pro / DePIN hardware inventory (extends `marketplace/*.md`)
- Cross-chain settlement: EVM, Solana, TON, Akash
- Great Delta EmissionRouter treasury routing on paid orders

## Existing anchors

- `marketplace/antminer-z15-inventory.md` — 26-unit inventory baseline
- `src/lib/db/models.ts` — payments user/transaction models
- `contracts/GreatDeltaEmissionRouter.sol` — 50/30/15/5 on-chain split

## Helical ingest

Consumes `mining-pools` attribution USD estimates for dynamic ASIC pricing tiers.

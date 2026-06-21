# Multi-Chain Treasury Architecture

YieldSwarm Instance B routes cross-chain yield and shard sweeps through a centralized **Treasury Registry** on the `cross_chain` program, orchestrated by **Nexus Chain (Solenoid 1)**.

## Two-Tier Treasury Model

| Tier | Role | Solana Program |
|------|------|----------------|
| **Nexus Treasury** | Primary on-chain profit sink for Helix / Solana internal yield | `TreasuryRegistry.nexus_treasury` |
| **Mining Roots** | DePIN and external-chain reward sinks (Base, ZEC, TAO, PRL, etc.) | `MiningRoot` PDAs per root kind |

### Nexus Treasury (Primary)

```
Solana: kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN
```

All internal Solana shard sweeps (`SWEEP_INTERNAL_SOLANA`) and default cross-chain inflows route SPL tokens to this pubkey's associated token account.

### Mining Roots (DePIN / External)

| Kind | Label | Chain | Address |
|------|-------|-------|---------|
| 0 | Base ETC | EVM | `0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00` |
| 1 | ZEC | Zcash | `t1KCti3km9DJLxYot3t7NgzYW2FpTnVCvrY` |
| 2 | PRL | Solana | `29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9` |
| 3 | TAO | Substrate | `5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF` |
| 4 | Base HYPE | EVM | `0x856e90EDd6d167355FcB6c35a8A857FFCA011Aa0` |
| 5 | Base cbETH | EVM | `0x455156dFDc95084A8e84e8d734a036A9a2e11Af0` |
| 6 | Base BTC | EVM | `0x1353f846DB707F6739591d294c80740607F1A87a` |

External roots (EVM, ZEC, TAO) settle on Solana via the Nexus custodial ATA first; `TreasuryRouteEvent` and `ShardSweepEvent` log the target external address for bridge relayers to complete outbound settlement. The Solana-native **PRL** root receives SPL transfers directly.

## On-Chain Accounts

### `TreasuryRegistry` PDA

Seeds: `[b"treasury_registry"]` on `cross_chain` program.

- `nexus_treasury` — primary Solana pubkey (default: Nexus address above)
- `nexus_authority` — Nexus Chain (Solenoid 1) signer for root updates
- `paused_sweeps` / `paused_inflows` — emergency pause flags
- `total_to_nexus` / `total_to_mining` — cumulative routing counters

### `MiningRoot` PDAs

Seeds: `[b"mining_root", root_kind]` on `cross_chain` program.

Each stores chain family, external address bytes, optional `solana_recipient`, and `total_routed`.

## Program Instructions

### cross_chain

| Instruction | Purpose |
|-------------|---------|
| `initialize_treasury_registry` | Bootstrap registry with Nexus Treasury |
| `initialize_mining_root` | Create one mining root from bootstrap table (call ×7) |
| `receive_cross_chain_yield` | Route bridged yield to Nexus or Mining Root (`route_destination`, `mining_root_kind`) |
| `set_treasury_pause` | Pause sweeps and/or inflows (admin or Nexus authority) |
| `update_mining_root` | Update root address (admin or Nexus authority) |
| `update_nexus_treasury` | Update Nexus pubkey (Nexus authority only) |

### shard_coordinator

| Instruction | Purpose |
|-------------|---------|
| `create_shard_vault` | Set `shard_type`, `sweep_destination`, `mining_root_kind` per shard |
| `sweep_shard_profits` | Sweep shard liquidity to Nexus Treasury or Mining Root |
| `rebalance_shards` | Only between shards with matching sweep routing config |

**Shard types:**

- `SWEEP_INTERNAL_SOLANA` (0) → must use `DEST_NEXUS_TREASURY`
- `SWEEP_EXTERNAL_MINING` (1) → must use `DEST_MINING_ROOT` + `mining_root_kind`

## Events

- `TreasuryRouteEvent` — logs `route_destination`, `mining_root_kind`, `solana_recipient`, and external address for every cross-chain inflow
- `ShardSweepEvent` — logs shard sweep destination and mining root kind
- `EventLog` kind `5` — pause state changes

## Nexus Chain (Solenoid 1) Integration

```
Nexus Chain (Solenoid 1)
        │
        ├── nexus_authority signs root updates / pause
        ├── Helix harvest triggers (cross_chain::trigger_remote_harvest)
        └── Bridge relayer reads TreasuryRouteEvent → outbound to Mining Roots

swarm_ops (521 agents)
        │
        └── propose_strategy / approve_strategy within spend limits
                └── CPI to cross_chain / shard_coordinator when consensus met

shard_coordinator
        │
        ├── rebalance_shards (compatible routing only)
        └── sweep_shard_profits → TreasuryRegistry accounting
```

1. Deploy `initialize_treasury_registry` with `nexus_authority` = Solenoid 1 ops key
2. Call `initialize_mining_root` for kinds `0..6`
3. Register agents in `swarm_ops`; proposals targeting treasury programs require multisig threshold
4. Indexer (`docs/INDEXER_GEYSER_SPEC.md`) ingests `TreasuryRouteEvent` and `ShardSweepEvent` into `telemetry/postgres/valhalla_indexer.sql`

## TypeScript SDK

```typescript
import {
  useTreasuryBalances,
  fetchTreasuryRegistry,
  resolveSweepDestination,
  NEXUS_TREASURY_SOLANA,
  MINING_ROOTS,
} from '@yieldswarm/cross-chain-sdk';
```

- `useTreasuryBalances()` — React hook for dashboard (Nexus + Mining Root totals)
- `fetchTreasuryRegistry()` / `fetchAllMiningRoots()` — off-chain readers
- `resolveSweepDestination(route, kind)` — human-readable routing label

## Deploy Sequence

```bash
# 1. Registry
anchor run initialize-treasury-registry -- --nexus-authority <SOLENOID_1_PUBKEY>

# 2. Mining roots (kinds 0-6)
for kind in 0 1 2 3 4 5 6; do
  anchor run initialize-mining-root -- --root-kind $kind
done

# 3. Coordinator (pass cross_chain program id)
anchor run initialize-coordinator -- --cross-chain-program CrossChn111...

# 4. Create shards with sweep config
anchor run create-shard-vault -- --shard-type 1 --sweep-destination 1 --mining-root-kind 2
```

## Security

- **Admin**: `TreasuryRegistry.authority` — full root updates + pause
- **Nexus**: `TreasuryRegistry.nexus_authority` — root updates, pause, Nexus treasury rotation
- **Pause**: `paused_sweeps` blocks `sweep_shard_profits`; `paused_inflows` blocks `receive_cross_chain_yield`
- **swarm_ops**: Agent spend limits still gate strategy proposals independently

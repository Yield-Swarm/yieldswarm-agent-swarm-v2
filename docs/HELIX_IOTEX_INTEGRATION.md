# Helix IoTeX / IOPAY Integration

Solenoid 2 (Helix) routes cross-chain yields to the IoTeX treasury and BTC bridge defined in `config/TREASURY_MANIFEST.json`.

## Treasury destinations

| Destination | ID | Address |
|-------------|-----|---------|
| Nexus Treasury (Solana) | `nexus_treasury` | `kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN` |
| IoTeX Treasury | `iotex_treasury` | `0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567` |
| BTC via IOPAY | `btc_via_iopay` | `bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8` |

## On-chain program (`cross_chain`)

### Instructions

- `configure_treasury_routing` — initializes `TreasuryRoutingConfig` PDA with IoTeX EVM bytes + BTC bridge hash
- `route_cross_chain_yield` — routes yield to Nexus, IoTeX, or BTC/IOPAY destination

### Chain IDs

| Chain | Constant | Value |
|-------|----------|-------|
| Solana | `CHAIN_SOLANA` | `0` |
| Helix | `CHAIN_HELIX` | `0x484c58` |
| IoTeX | `CHAIN_IOTEX` | `0x1250` (4689) |
| IOPAY BTC | `CHAIN_IOPAY_BTC` | `0x494f50` |

### Events

- `IotexYieldRouted` — emitted on IoTeX or BTC/IOPAY routing
- `EventLog` kind `3` (`EVENT_KIND_IOTEX_INFLOW`) — indexer consumption

## SDK

```typescript
import {
  CrossChainClient,
  YIELD_DEST_IOTEX,
  YIELD_DEST_BTC_IOPAY,
  resolveIotexRoutingFromManifest,
} from '@yieldswarm/onchain-sdk';

const client = new CrossChainClient(connection);
const routing = resolveIotexRoutingFromManifest();

// Route to IoTeX treasury
client.buildRouteToIotexIx(relayer, treasuryPda, 1_000_000n, CHAIN_IOTEX);

// Route to BTC via IOPAY
client.buildRouteToBtcIopayIx(relayer, treasuryPda, amount);
```

Manifest defaults live in `onchain/sdk/src/treasury/defaults.ts` (sync with `config/TREASURY_MANIFEST.json`).

## Backend API

| Endpoint | Description |
|----------|-------------|
| `GET /api/treasury/manifest` | Full treasury manifest |
| `GET /api/treasury/iotex` | IoTeX hub + BTC bridge hash |
| `GET /api/treasury/mining-roots` | All mining root addresses |

## Environment + Vault

Env vars: see `.env.example` (`NEXUS_TREASURY_SOLANA`, `MINING_ROOT_*`, `IOTEX_*`).

Vault paths (KV v2 mount `yieldswarm`):

```text
yieldswarm/treasury/manifest
yieldswarm/treasury/mining_roots
yieldswarm/iotex/hub
yieldswarm/iotex/api
```

Policy: `vault/policies/treasury-runtime.hcl`

Seed: `vault/scripts/seed-secrets.sh`

## Agent workflow

1. Agent registered in `swarm_ops` with `daily_spend_limit`
2. Agent triggers `trigger_remote_harvest` with `origin_chain_id = CHAIN_IOTEX`
3. Relayer calls `route_cross_chain_yield` with destination:
   - `YIELD_DEST_IOTEX` (1) for IoTeX treasury
   - `YIELD_DEST_BTC_IOPAY` (2) for BTC bridge
4. Off-chain IOPAY relayer completes EVM/BTC settlement using manifest addresses
5. Indexer ingests `IotexYieldRouted` → `iotex_yield_events` table

## Security notes

- Treasury addresses are public; private keys never belong in the manifest
- Store `IOTEX_API_KEY` only in Vault (`yieldswarm/iotex/api`)
- Rotate bridge relayer keys via Vault policies in `treasury-runtime.hcl`

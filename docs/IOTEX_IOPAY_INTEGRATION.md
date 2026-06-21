# IoTeX + IOPAY Integration (Helix Solenoid 2)

Native IoTeX routing for cross-chain yield settlement via the Treasury Manifest.

## Addresses

| Role | Address |
|------|---------|
| IoTeX Treasury | `0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567` |
| BTC via IOPAY | `bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8` |
| Nexus Treasury (Solana) | `kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN` |

## Configuration

### Treasury Manifest

`config/treasury/TREASURY_MANIFEST.json` — version 2.0 with `mining_roots` and `iotex_hub`.

### Environment Variables

```bash
NEXUS_TREASURY_SOLANA=kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN
IOTEX_TREASURY=0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567
IOTEX_BTC_BRIDGE=bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8
MINING_ROOT_IOTEX=0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567
MINING_ROOT_BTC_VIA_IOPAY=bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8
```

### HashiCorp Vault

| Path | Keys |
|------|------|
| `secret/yieldswarm/treasury/mining_roots` | `base_etc`, `zec`, `prl`, `tao`, `base_hype`, `base_cbeth`, `base_btc`, `iotex`, `btc_via_iopay` |
| `secret/yieldswarm/iotex` | `treasury`, `btc_bridge`, `nexus_treasury_solana` |

See `vault/policies/iotex-treasury.hcl` and `vault/scripts/seed-secrets.sh`.

## API (Helix)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/helix/treasury/manifest` | Treasury Manifest v2 |
| GET | `/api/helix/iotex/status` | IoTeX hub readiness + inflow count |
| POST | `/api/helix/yield/receive` | Route yield to IoTeX or BTC bridge |

### Receive yield

```bash
curl -X POST http://localhost:8080/api/helix/yield/receive \
  -H 'Content-Type: application/json' \
  -d '{
    "amount": "100",
    "asset": "IOTX",
    "sourceChain": "solana",
    "destination": "iotex_treasury",
    "agentId": "swarm-agent-01"
  }'
```

Destinations: `iotex_treasury` (default) | `btc_via_iopay`

## TypeScript SDK

```typescript
import { HelixIotexClient } from '../src/lib/helix/iotex';

const client = new HelixIotexClient('http://localhost:8080');
await client.routeToIotexTreasury('50', 'base', { agentId: 'agent-1' });
await client.routeToBtcViaIopay('0.001', 'ethereum', { asset: 'BTC' });
```

## Events

Each routed yield emits `IotexYieldInflow`:

```json
{
  "type": "IotexYieldInflow",
  "chain": "iotex",
  "destination": "iotex_treasury",
  "address": "0x8f3d03e4...",
  "amount": "100",
  "asset": "IOTX",
  "sourceChain": "solana",
  "timestamp": "2026-06-20T..."
}
```

Poll via `GET /api/helix/iotex/inflows`.

## Agent routing flow

```
Source chain yield → receive_cross_chain_yield (Helix API)
  → resolve destination from TREASURY_MANIFEST / env
  → emit IotexYieldInflow
  → (production) IOPAY bridge settlement to on-chain address
```

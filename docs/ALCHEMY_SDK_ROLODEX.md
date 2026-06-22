# Alchemy SDK Rolodex (June 2026)

Complete SDK catalog for **Christopher's First App** across **164+ Alchemy networks** (EVM + non-EVM). API key lives in Vault only — URLs are built at runtime from `config/alchemy/christophers-first-app.json`.

## Core stack

| Language | SDK | YieldSwarm use |
|----------|-----|----------------|
| **TypeScript** | **Viem** + Alchemy RPC | Frontend, Arena, backend routes |
| **TypeScript** | `@solana/web3.js` | Solana telemetry, DePIN |
| **Python** | `web3.py` | Sovereign loops, Kairo, mining |
| **Python** | `solana-py` | Solana reads / Kairo pipeline |
| **Rust** | `solana-client` | Performance-critical Solana |
| **Any** | JSON-RPC | Smoke tests, custom probes |

Legacy `alchemy-sdk` is optional; prefer **Viem + direct RPC** for new code.

## Repo integration

| Component | Path |
|-----------|------|
| Network manifest | `config/alchemy/christophers-first-app.json` |
| Python Rolodex | `services/alchemy/client.py` → `AlchemyRolodex` |
| TypeScript / Viem | `src/lib/alchemy/client.ts` |
| Backend (Express) | `backend/src/lib/alchemy.js` |
| Vault key | `yieldswarm/integrations/alchemy` → `api_key` |
| Vault fallback | `yieldswarm/rpc/ethereum` → `alchemy_api_key` |
| Akash injection | `ALCHEMY_API_KEY` in `akash/templates/runtime.env.ctmpl` |

## Python (sovereign loops, Kairo)

```python
from services.alchemy import AlchemyRolodex

rolodex = AlchemyRolodex()  # key from Vault or ALCHEMY_API_KEY
rolodex.apply_env_defaults()

w3 = rolodex.web3("ethereum-mainnet")
block = w3.eth.block_number

sol = rolodex.solana_client()
slot = sol.get_slot()

for result in rolodex.ping_defaults():
    print(result.network_id, result.ok, result.block_or_slot)
```

## TypeScript (frontend / Arena)

```ts
import { createAlchemyPublicClient, alchemyRpcUrl } from '@/lib/alchemy/client';

const client = createAlchemyPublicClient('base-mainnet');
const block = await client?.getBlockNumber();

const url = alchemyRpcUrl('solana-mainnet'); // for @solana/web3.js Connection
```

## Viem EVM pattern

```ts
import { createPublicClient, http } from 'viem';
import { base } from 'viem/chains';

const client = createPublicClient({
  chain: base,
  transport: http(alchemyRpcUrl('base-mainnet')),
});
```

## Vault seed (never commit key)

```bash
export ALCHEMY_API_KEY=...
export ALCHEMY_APP_NAME="Christopher's First App"
./vault/scripts/seed-secrets.sh
```

Do **not** store full RPC URLs with embedded keys in Vault — the Rolodex derives URLs from `api_key` + manifest.

## Chain families

| Family | Networks | Client |
|--------|----------|--------|
| EVM | Ethereum, Base, Arbitrum, OP, Polygon, Linea, Scroll, … | Viem / web3.py |
| Solana | Mainnet, Devnet | `@solana/web3.js` / solana-py |
| Starknet | Mainnet, Sepolia | starknet.js / JSON-RPC |
| Bitcoin, Sui, Aptos | Per manifest | Family-specific SDK + Alchemy RPC |

## API routes (backend)

| Route | Description |
|-------|-------------|
| `GET /api/rpc/alchemy/health` | Key configured |
| `GET /api/rpc/alchemy/endpoints` | Full catalog (URLs redacted) |
| `GET /api/rpc/alchemy/defaults` | Primary chain URLs |

## Install

```bash
npm install viem @solana/web3.js
pip install web3 solana
```

## Related

- [`docs/ALCHEMY_CHRISTOPHERS_FIRST_APP.md`](ALCHEMY_CHRISTOPHERS_FIRST_APP.md)
- [`docs/RPC_ALCHEMY_STUDY.md`](RPC_ALCHEMY_STUDY.md)
- [`SECRETS.md`](../SECRETS.md) §9 — Vault paths

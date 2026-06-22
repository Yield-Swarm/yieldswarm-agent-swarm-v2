# RPC Mesh Study — Christopher's First App (Alchemy)

**Date:** 2026-06-15 · **Branch:** `cursor/alchemy-christophers-first-app-9c82`  
**Manifest:** `config/alchemy/christophers-first-app.json` (164 networks)

## Executive summary

YieldSwarm now routes cross-chain reads, DEX quotes, treasury attestations, and Helix/Nexus orchestration through a **single Alchemy app** (“Christopher's First App”) instead of ad-hoc public RPCs. When `ALCHEMY_API_KEY` is set, the integration backend **auto-fills** unset chain RPC env vars at boot; explicit env values always win.

| Metric | Value |
|--------|-------|
| Total networks in manifest | **164** |
| Enabled | **164** |
| EVM L1/L2/L3 | **138** |
| Solana | **2** (mainnet + devnet) |
| UTXO (BTC family) | **9** |
| Beacon (ETH consensus) | **3** |
| Starknet | **2** |
| Sui, Stellar, Cosmos, Tron, Aptos | **2 each** |

## Network families

```text
evm      138   Ethereum, Base, Polygon, Arbitrum, Optimism, Avalanche, L2s, testnets
utxo       9   Bitcoin + test variants
beacon     3   Ethereum beacon (mainnet, sepolia, hoodi)
solana     2   mainnet, devnet
starknet   2   mainnet, sepolia
sui        2   mainnet, testnet
stellar    2   mainnet, testnet
cosmos     2   mainnet, testnet
tron       2   mainnet, testnet
aptos      2   mainnet, testnet
```

**Note:** IoTeX mainnet is **not** in the Alchemy catalog; Helix routes IoTeX via `YIELD_DEST_IOTEX` / dedicated node or public RPC. Mining root `0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567` remains in `config/TREASURY_MANIFEST.json`.

## Primary chains (YieldSwarm defaults)

These are the chains the backend resolves first when bootstrapping RPC env:

| Alias | Network ID | Host | Auto-filled env var(s) |
|-------|------------|------|------------------------|
| Solana | `solana-mainnet` | `solana-mainnet.g.alchemy.com` | `SOLANA_RPC_URL` |
| Ethereum | `ethereum-mainnet` | `eth-mainnet.g.alchemy.com` | `ETHEREUM_RPC_URL`, `EVM_RPC_URL`, `MAINNET_RPC_URL` |
| Base | `base-mainnet` | `base-mainnet.g.alchemy.com` | `BASE_RPC_URL`, `EVM_RPC_URL_8453` |
| Polygon | `polygon-mainnet` | `polygon-mainnet.g.alchemy.com` | `EVM_RPC_URL_137` |
| Arbitrum | `arbitrum-mainnet` | `arb-mainnet.g.alchemy.com` | `EVM_RPC_URL_42161` |
| Sepolia | `ethereum-sepolia` | `eth-sepolia.g.alchemy.com` | `SEPOLIA_RPC_URL` |
| Optimism | `op-mainnet` | `opt-mainnet.g.alchemy.com` | (via `resolveAlchemyDefaults` only) |
| Avalanche | `avalanche-mainnet` | `avax-mainnet.g.alchemy.com` | (via `resolveAlchemyDefaults` only) |

URL pattern: `https://{host}/v2/{ALCHEMY_API_KEY}` (Starknet uses `/starknet/version/rpc/v0_10/{key}`).

## Wiring (what was built)

| Component | Path |
|-----------|------|
| Manifest generator | `scripts/alchemy/build-manifest.py` |
| Print env defaults | `scripts/alchemy/print-defaults.sh` |
| Resolver + bootstrap | `backend/src/lib/alchemy.js` |
| HTTP API | `backend/src/routes/rpc.js` → `/api/rpc/alchemy/*` |
| Config hook | `backend/src/config.js` (calls `applyAlchemyRpcEnvDefaults` on load) |
| Vault seed | `yieldswarm/data/integrations/alchemy` via `vault/scripts/seed-secrets.sh` |
| Operator doc | `docs/ALCHEMY_CHRISTOPHERS_FIRST_APP.md` |

## API endpoints (operator pane)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/api/rpc/alchemy/health` | Key configured? App name |
| `GET` | `/api/rpc/alchemy/endpoints` | Full 164-network catalog (URLs redacted) |
| `GET` | `/api/rpc/alchemy/defaults` | Primary chain URLs currently in use |
| `GET` | `/api/rpc/alchemy/url/:networkId` | Single network URL (`?reveal=1` only if `ALCHEMY_REVEAL_URLS=1`) |

```bash
# Health (no key required for structure; live=false without key)
curl -s http://127.0.0.1:8080/api/rpc/alchemy/health | jq

# Catalog count
curl -s http://127.0.0.1:8080/api/rpc/alchemy/endpoints | jq '.count, .app'

# What the backend actually uses for Helix/DEX/treasury
curl -s http://127.0.0.1:8080/api/rpc/alchemy/defaults | jq
```

## Bootstrap behavior

1. Backend loads `ALCHEMY_API_KEY` from env or Vault-injected runtime.
2. `applyAlchemyRpcEnvDefaults()` runs once at startup.
3. For each mapping in `alchemy.js`, if the env var is **unset**, it is filled with the Alchemy URL.
4. DEX (`/api/dex/*`), cross-chain MVP, and wallet SDK reads inherit the same RPC mesh.

**Invariant:** Never commit the API key. Rotate immediately if exposed in chat or logs.

## Tri-solenoid + RPC placement

```text
                    ┌─────────────────────────────────────┐
                    │   Alchemy RPC Mesh (164 networks)   │
                    │   GET /api/rpc/alchemy/*            │
                    └──────────────┬──────────────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
  Solenoid 1 Nexus          Solenoid 2 Helix          Solenoid 3 Shadow
  orchestration             mining roots + IoTeX       Arena + reputation
  /api/nexus/*              onchain/programs/helix     /api/shadow/*
```

- **Nexus** dispatches cross-solenoid jobs; RPC is used for EVM read/simulate before multicloud launch.
- **Helix** routes yield to 10 mining roots (`config/TREASURY_MANIFEST.json`); EVM roots use Alchemy; IoTeX uses dedicated routing.
- **Shadow/Arena** competition scores feed back into harvest priority (`bittensor` first in gospel).

## Mining + pool pointers

All community mining should **point payouts** at YieldSwarm treasury and mining roots (see `README.md` § Mine With Us):

| Asset | Address / pool |
|-------|----------------|
| Nexus Treasury (Solana) | `kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN` |
| IoTeX hub | `0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567` |
| BTC (IOPAY bridge) | `bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8` |
| Bittensor | Join our Akash miner — `BT_NETUID=1`, `BT_NETWORK=finney` |

Revenue from any venue still passes through **Great Delta 50/30/15/5** (`agents/governance/gospel.py`).

## Recommendations

1. **Rotate** any API key that appeared in chat or screenshots.
2. Set `ALCHEMY_API_KEY` in Vault for Akash/Render; use `.env` locally only.
3. For IoTeX-specific workloads, keep `YIELD_DEST_IOTEX` and a dedicated IoTeX RPC alongside Alchemy.
4. Use `/api/rpc/alchemy/health` in deploy smoke tests alongside `/api/helix/status` and `/api/nexus/health`.
5. Regenerate manifest after Alchemy dashboard changes: `python3 scripts/alchemy/build-manifest.py`.

## Related docs

- `docs/ALCHEMY_CHRISTOPHERS_FIRST_APP.md` — setup + Vault
- `docs/TRI_SOLENOID_ARCHITECTURE.md` — Nexus / Helix / Shadow
- `SINGLE_PANE_OF_GLASS.md` — updated operator diagram
- `agents/governance/gospel.py` — RPC mesh + mining covenant constants

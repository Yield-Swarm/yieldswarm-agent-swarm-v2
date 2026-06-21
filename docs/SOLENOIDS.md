# Three-Solenoid Architecture

Production orchestration layer for YieldSwarm AgentSwarm OS v2: **Nexus Chain**, **Helix Reverberator**, and **Shadow Chain** (Kyle's chain).

## Overview

| Solenoid | Role | On-chain | Off-chain API |
|----------|------|----------|---------------|
| **1 — Nexus** | Central orchestration, 521-agent registry, messaging bus, multi-cloud | `programs/coordinator` | `/api/nexus/*` |
| **2 — Helix** | Multi-chain treasury routing, IoTeX hub, ZK-Swarm proofs | `programs/cross_chain`, `programs/swarm_ops` | `/api/helix/treasury/*` |
| **3 — Shadow** | Arena competition, reputation, rewards | `programs/arena` | `/api/shadow/arena/*` |

All solenoids pull secrets from **HashiCorp Vault** via dedicated AppRole policies.

## Solenoid 1 — Nexus Chain

```
solenoids/nexus/
├── registry.js       # SolenoidRegistry (521 agents)
├── messageBus.js     # Cross-solenoid pub/sub
├── resourceManager.js # Azure / Akash / Vast.ai
├── vaultSecrets.js   # AppRole KV fetcher
└── index.js          # NexusOrchestrator
```

### API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/nexus/status` | Registry + bus + resource snapshot |
| POST | `/api/nexus/agents/register` | Register agent (cap 521) |
| POST | `/api/nexus/resources/allocate` | Allocate cloud GPU/CPU |
| POST | `/api/nexus/bus/publish` | Cross-solenoid message |
| POST | `/api/nexus/pause` | Global emergency pause |

## Solenoid 2 — Helix Reverberator

Mining Roots and IoTeX routing are defined in `config/TREASURY_MANIFEST.json`:

- `base_etc`, `zec`, `prl`, `tao`, `base_hype`, `base_cbeth`, `base_btc`
- **`iotex`** — `0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567`
- `btc_via_iopay`

On-chain: `register_mining_root` and `route_yield_to_root` in `programs/cross_chain`.

### API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/helix/treasury` | Mining Roots manifest |
| POST | `/api/helix/treasury/route` | Split yield across roots |
| POST | `/api/helix/settlement/quote` | Dry-run harvest quote |
| POST | `/api/helix/zk/batch` | ZK-Swarm proof batch |

## Solenoid 3 — Shadow Chain (Kyle's chain)

Arena program (`programs/arena`) integrates with `swarm_ops` agent registry and supports **ZK-Swarm Mutation** batched proofs.

### API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/shadow/arena/status` | Season, pool, leaderboard |
| POST | `/api/shadow/arena/register` | Register competitor (requires swarm_ops) |
| POST | `/api/shadow/arena/score` | Submit score + reputation |
| POST | `/api/shadow/arena/zk-batch` | Batched mutation proofs |
| POST | `/api/shadow/arena/rewards` | Distribute rewards |

## HashiCorp Vault

### Policies

| Policy | Solenoid | Paths |
|--------|----------|-------|
| `nexus-runtime` | Nexus | `runtime/nexus`, `providers/azure`, `providers/akash`, `providers/vastai` |
| `helix-runtime` | Helix | `runtime/helix`, `runtime/wallets`, `runtime/zk`, `rpc/*` |
| `shadow-runtime` | Shadow | `runtime/shadow`, `runtime/zk`, `runtime/backend` |

### Dynamic injection

```bash
# Azure TEE / control plane
PROVIDER=azure ./vault/inject/render-env.sh

# Akash SDL workloads
PROVIDER=akash ./vault/inject/render-env.sh

# Vast.ai GPU workers (Helix yield compute)
PROVIDER=vastai ./vault/inject/render-env.sh
```

Seed solenoid paths:

```bash
export NEXUS_COORDINATOR_KEY=... HELIX_CHAIN_BRIDGE_KEY=... SHADOW_ARENA_AUTHORITY=...
./vault/scripts/seed-secrets.sh
```

## Deploy sequence

1. `vault/setup/bootstrap.sh` — enable engines + policies
2. `./vault/scripts/seed-secrets.sh` — populate KV paths
3. `anchor build && anchor deploy` — coordinator, cross_chain, swarm_ops, arena
4. `cd backend && npm install && npm test`
5. `npm start` — Nexus + Helix + Shadow APIs live

## Program IDs (devnet/localnet)

| Program | ID |
|---------|-----|
| coordinator | `DXGVx4HsitGdFawg5KL68SAq9URhTaNL9tZAWWGGbo7p` |
| cross_chain | `9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt` |
| swarm_ops | `6BbH4rvmxERTbcAbEat9SzT3N3P9fEFWvoAD3EsJ3BAz` |
| arena | see `Anchor.toml` |

See also: `docs/VAULT_ENV_INJECTION.md`, `HELIX.md`, `config/solenoids.json`.

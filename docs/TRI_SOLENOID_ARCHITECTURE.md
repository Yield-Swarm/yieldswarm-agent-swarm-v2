# Tri-Solenoid Architecture — Nexus, Helix, Shadow Chain

Production orchestration layer for YieldSwarm's three solenoids. All runtimes pull secrets from HashiCorp Vault via AppRole policies.

## Solenoids

| # | Name | Role | Program | Vault Policy |
|---|------|------|---------|--------------|
| 1 | **Nexus Chain** | Central orchestration (521 agents) | — | `nexus-runtime` |
| 2 | **Helix Reverberator** | Cross-chain yield + IoTeX routing | `helix` | `helix-runtime` |
| 3 | **Shadow Chain** | Arena competition (Kyle's chain) | `arena` | `shadow-chain-runtime` |

## Nexus Chain (Solenoid 1)

- **Registry**: `services/nexus/registry.py` — 521-agent capacity, solenoid discovery
- **Messaging bus**: `services/nexus/messaging.py` — durable JSONL cross-solenoid pub/sub
- **Multicloud**: `services/nexus/multicloud.py` — Akash, Azure, Vast.ai launch orchestration
- **API**: `GET/POST /api/nexus/*` — health, registry, dispatch, multicloud launch
- **Config**: `config/nexus/solenoids.yaml`

```bash
python3 services/nexus/cli.py status
python3 services/nexus/cli.py register-agent agent-001 shadow 42
python3 services/nexus/cli.py dispatch helix trigger_remote_harvest '{"origin_chain_id":4680,"amount":1000}'
```

## Helix Reverberator (Solenoid 2)

Anchor program at `onchain/programs/helix/`:

- **Mining roots** (10 destinations) synced with `config/TREASURY_MANIFEST.json`
- **IoTeX hub** routing via `YIELD_DEST_IOTEX` and `CHAIN_IOTEX`
- **ZK-Swarm** batched proofs via `submit_zk_swarm_batch`
- Program ID: `Helx1111111111111111111111111111111111111`

Instructions:

| Instruction | Purpose |
|-------------|---------|
| `initialize_helix` | Bootstrap Helix state + Nexus treasury |
| `configure_mining_roots` | Set IoTeX, BTC bridge, and 10 root hashes |
| `route_to_mining_root` | Route yield to any mining root |
| `submit_zk_swarm_batch` | Verify ZK-Swarm proof batch |

## Shadow Chain (Solenoid 3)

Arena program at `onchain/programs/arena/` — Kyle's chain:

- **Competition**: `submit_performance` with arena score, signal precision, PnL
- **Reputation**: dynamic reputation with `slash_reputation`
- **Rewards**: epoch-based `distribute_rewards` weighted by reputation
- **swarm_ops CPI**: `register_competitor` calls `swarm_ops::register_agent`
- **ZK-Swarm Mutation**: `submit_zk_swarm_batch` with mutation epoch
- Program ID: `Arna1111111111111111111111111111111111111`
- API: `GET /api/shadow/status`, `GET /api/shadow/vault/injection/:provider`

## HashiCorp Vault Integration

### Policies

| Policy | Solenoid | Key Paths |
|--------|----------|-----------|
| `nexus-runtime.hcl` | Nexus | `treasury/*`, `runtime/nexus`, `cloud/*`, `providers/*` |
| `helix-runtime.hcl` | Helix | `treasury/*`, `iotex/hub`, `runtime/helix`, `runtime/wallets` |
| `shadow-chain-runtime.hcl` | Shadow | `runtime/shadow`, `runtime/zk`, `runtime/backend` |

### Dynamic Secret Injection

Vault Agent templates in `vault/templates/`:

| Provider | Template | Output |
|----------|----------|--------|
| Akash | `akash-runtime.ctmpl` | Container env for sovereign core + agents |
| Azure | `azure-runtime.ctmpl` | `/etc/yieldswarm/nexus.env` on VM/ACI |
| Vast.ai | `vast-runtime.ctmpl` | GPU burst worker env |

```bash
python3 services/vault/cli.py list
python3 services/vault/cli.py spec azure nexus
```

### Seeding

```bash
export VAULT_ADDR=... VAULT_TOKEN=...
export NEXUS_CHAIN_URL=... HELIX_CHAIN_URL=... SHADOW_CHAIN_URL=...
export MINING_ROOT_IOTEX=0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567
./vault/scripts/seed-secrets.sh
```

## Cross-Solenoid Messaging

Nexus bus routes events between solenoids:

- `nexus → helix`: `trigger_remote_harvest`
- `shadow → nexus`: `arena_score`

Bus state: `.run/nexus-bus.jsonl`

## Build

```bash
cd onchain && anchor build   # requires Anchor 0.30.1
```

Programs registered in `onchain/Cargo.toml` and `onchain/Anchor.toml`.

## Phase 2 EVM (Solidity)

Layer-parallel smart contracts in `contracts/solenoid/` interlock with the Rust runtime:

| Layer | EVM | Rust/Anchor |
|-------|-----|-------------|
| Nexus | `contracts/solenoid/Nexus.sol` | `services/nexus/` |
| Helix | `contracts/solenoid/Helix.sol` | `onchain/programs/helix/` |
| Shadow | `contracts/solenoid/Shadow.sol` | `onchain/programs/arena/` |

```bash
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts
FOUNDRY_PROFILE=solenoid forge test -vv
```

See `docs/SOLENOID_PHASE2_EVM.md`.

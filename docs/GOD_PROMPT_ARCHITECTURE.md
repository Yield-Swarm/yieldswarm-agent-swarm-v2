# God Prompt Helical Architecture

Three-layer helical model (C¹ + L¹) for YieldSwarm — every major component integrates Greek (structure), Eastern (flow), and Paradigm Shift (co-creation) layers.

## Layer map

| Layer | Focus | Key modules |
|-------|-------|-------------|
| **Greek (D¹)** | Isolation, boundaries, auditability | `odysseus-router.js`, `resource-guardrails.js`, smart contract interfaces |
| **Eastern (E¹)** | Emergence, feedback loops, adaptation | `sovereign-optimizer.js`, `entropy-core.js`, Arena ↔ mutation recursion |
| **Paradigm Shift (PDs¹)** | Co-evolution, new realities | NFT mutation, `dydx-bridge.js`, Chainlink hybrid oracle |

## Build order (implemented)

1. **Smart contracts** — `contracts/YieldSwarmNFT.sol`, `MutationController.sol`, `MultiSplitLeasing.sol`, `TokenStakingPool.sol`
2. **Sovereign Optimizer v6** — `src/infrastructure/sovereign-optimizer.js`
3. **Odysseus Router** — `src/infrastructure/odysseus-router.js`
4. **dYdX v4 bridge** — `src/infrastructure/dydx-bridge.js`
5. **vLLM RTX 5090** — `deploy/Dockerfile.bert`, `deploy/entrypoint.bert.sh`

## Cross-layer integration

```
Arena telemetry → entropy-core → mutate-agent.js → MutationController
       ↓                                    ↓
sovereign-optimizer ← NFT tier + staking boost
       ↓
odysseus-router (isolated context per tokenId) → vLLM 5090 worker
       ↓
dydx-bridge (tier-aware notional) → Great Delta treasury split
```

## Deploy

```bash
# Contracts (requires Foundry)
forge build && forge test

# Infrastructure tests
npm run test:unit -- src/infrastructure/

# vLLM 5090 on Akash
docker build -f deploy/Dockerfile.bert -t ghcr.io/yield-swarm/vllm-5090:latest .
```

## Cloud credits (30-day)

Use `$5,408` credits aggressively via existing multicloud scripts:

```bash
make multicloud-preflight
make multicloud-launch   # Akash, Vast, RunPod, Azure, GCP, AWS, Alibaba
```

Wire RTX 5090 profile in `deploy/deploy-swarm-monolith.yaml` GPU model field when upgrading from 3090.

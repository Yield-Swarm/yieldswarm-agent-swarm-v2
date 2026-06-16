# Tri-Layer Helical Architecture

> Greek ($D^1$) · Eastern ($E^1$) · Paradigm Shift ($PDs^1$)

## Layer map

| Layer | Domain | Key artifacts |
|-------|--------|---------------|
| **$D^1$ Greek** | Immutable boundaries | `contracts/YieldSwarmNFT.sol`, `contracts/MultiSplitLeasing.sol`, `deploy/entrypoint.monitor.sh` |
| **$E^1$ Eastern** | Context & entropy | `src/infrastructure/odysseus-router.js`, `src/infrastructure/entropy-core.js` |
| **$PDs^1$ Paradigm Shift** | ZK + trading + mutation | `circuits/entropy_proof.circom`, `src/infrastructure/dydx-bridge.js`, `functions/mutate-agent.js` |
| **Bare-metal** | vLLM scaling + credits | `deploy/Dockerfile.bert`, `deploy/entrypoint.bert.sh`, `src/infrastructure/sovereign-optimizer.js` |

## Quick start

```bash
# Compile Greek layer contracts
forge build
forge test --match-contract "YieldSwarmNFTTest|MultiSplitLeasingTest"

# Run Eastern + Paradigm Shift unit tests
npm run test:unit

# Launch vLLM worker (RTX 5090 + AWQ)
docker build -f deploy/Dockerfile.bert -t yieldswarm-bert .
docker run --gpus all -p 8000:8000 yieldswarm-bert

# Hardware guardrail monitor
./deploy/entrypoint.monitor.sh <workload-pid>
```

## Parallel agent teams

See the Master God Prompt execution commands — each team owns an isolated directory boundary to prevent merge drift.

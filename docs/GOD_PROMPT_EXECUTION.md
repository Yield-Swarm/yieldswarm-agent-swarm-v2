# God Prompt — Aggressive Execution Runbook

Use alongside the expanded 5-layer spec. One sprint, strict order.

## Execute now

```bash
# 1. ZK circuit (ZK¹)
cd circuits && npm install && npm run full-build

# 2. Tests (all layers)
npm run test:zk && npm run test:god-prompt

# 3. Contracts (D¹ + PDs¹)
forge build && forge test

# 4. Deploy verifier → wire MutationController
# export ENTROPY_VERIFIER=0x... MUTATION_CONTROLLER=0x...
```

## 50-task map (compressed)

| Tasks | Layer | Deliverable |
|-------|-------|-------------|
| 1–10 | D¹ | `circuits/`, `zk-entropy-prover.js`, `ZK_CIRCUIT_SPEC.md`, ACL + errors |
| 11–20 | E¹ | `entropy-core.js` ZK witness, async prover, optimizer feedback |
| 21–30 | C¹+L¹ | `zk-proof-queue.js`, `HELIX_ZK_OSCILLATOR.md` |
| 31–40 | ZK¹ | `entropy_proof.circom`, setup scripts, verifier, tests |
| 41–50 | PDs¹ | `MutationController` ZK gate, e2e tests, README, architecture docs |

## Parallel agent split (optional)

| Agent | Tasks | Branch prefix |
|-------|-------|---------------|
| A | 1–10, 31–34 | `cursor/zk-d1-circuit-d1cd` |
| B | 11–20, 35–38 | `cursor/zk-e1-prover-d1cd` |
| C | 21–30 | `cursor/zk-helix-queue-d1cd` |
| D | 41–50 | `cursor/zk-pds-contracts-d1cd` |

Merge order: A → B → C → D into `main`.

## Gates

- `npm run test:zk` must pass before mainnet
- Groth16 artifacts required (no `dev-hash` on mainnet)
- MPC ceremony for production zkey

# ZK Entropy System — Security Model & Flow (Tasks 40, 48, 50)

## Objective

Cryptographically prove entropy seeds were derived from valid hardware telemetry **without revealing raw telemetry**, integrated across all **5 helical layers**.

## End-to-end flow

```
GPU telemetry (private)
       ↓
entropy-core.js — rolling window + circuit inputs (E¹)
       ↓
zk-entropy-prover.js — Groth16 proof (ZK¹)
       ↓
MutationController.executeMutationWithProof (PDs¹)
       ↓
YieldSwarmNFT genome update
       ↓
sovereign-optimizer routing boost (E¹ + C¹+L¹ feedback)
```

## Layer integration

### D¹ — Greek (Structure & Isolation)
- `circuits/entropy_proof.circom` hard range constraints
- `ZkEntropyProver.sanitizeInputs()` before proving
- `MutationController` proof submitter ACL + explicit revert reasons
- Clean module separation: `entropy-core` ≠ `zk-entropy-prover` ≠ contracts

### E¹ — Eastern (Flow & Emergence)
- Async proof generation (non-blocking)
- Graceful degradation to `dev-hash` when artifacts missing
- Proof success/failure feeds `sovereign-optimizer` routing
- High-quality proofs → routing priority boost

### C¹ + L¹ — Helix Oscillator
- `zk-proof-queue.js` rhythmic batch scheduling
- Pauses during thermal/VRAM pressure
- Non-linear batch sizing from cluster load
- Proof timing influences optimizer rhythm

### ZK¹ — Entropy & ZK
- Poseidon-bound entropy seeds
- Groth16 trusted setup (Powers of Tau + circuit phase)
- `EntropyProofVerifier.sol` on-chain verification
- Circuit registry v1.0.0 with upgrade path

### PDs¹ — Paradigm Shift
- NFT mutation requires valid ZK proof when `zkProofRequired=true`
- Entropy quality influences mutation/routing outcomes
- Chainlink Functions `mutate-agent.js` ZK-aware submission
- Hardware ↔ digital identity co-evolution loop

## Security model

| Threat | Mitigation |
|--------|------------|
| Fake telemetry | Range constraints + Poseidon binding; prover must know preimage |
| Replay | `nonce` + `tokenId` + scheduled entropy match on-chain |
| Unauthorized mutation | `proofSubmitters` ACL on `executeMutationWithProof` |
| Verifier compromise | Production MPC ceremony; dev verifier isolated to testnet |
| Slow proving DoS | Queue pauses + graceful degradation |

## Error codes

| Code | Layer | Meaning |
|------|-------|---------|
| `ZK_INVALID_INPUT` | D¹ | Non-numeric or missing input |
| `ZK_RANGE_VIOLATION` | D¹ | Telemetry outside circuit bounds |
| `ZK_PROVE_TIMEOUT` | E¹ | Proving exceeded deadline |
| `ZK_ARTIFACT_MISSING` | ZK¹ | WASM/zkey not built |
| `InvalidEntropyProof` | on-chain | Groth16 verify failed |
| `EntropySeedMismatch` | on-chain | Proof seed ≠ scheduled seed |

## Setup

```bash
# 1. Build circuit
cd circuits && npm install && npm run full-build

# 2. Deploy verifier + wire MutationController
export MUTATION_CONTROLLER=0x...
export ENTROPY_VERIFIER=0x...

# 3. Run prover
node -e "
import { ZkEntropyProver } from './src/infrastructure/zk-entropy-prover.js';
const p = new ZkEntropyProver();
console.log(await p.generateProof({ telemetry: { gpuTempC: 70, vramUsedPct: 60, powerWatts: 400, inferenceTps: 100, packetLossPct: 1, nodeProfile: 'rtx5090' }, tokenId: '1', nonce: 1 }));
"

# 4. Tests
npm run test:zk
```

## Testnet vs mainnet

| Environment | Verifier | Prover mode |
|-------------|----------|-------------|
| Local dev | `DevEntropyProofVerifier` | `dev-hash` fallback |
| Testnet | Generated or Dev | Groth16 if artifacts present |
| Mainnet | `EntropyProofVerifier` + MPC zkey | Groth16 only |

## Related docs

- `docs/ZK_CIRCUIT_SPEC.md` — signal definitions
- `docs/HELIX_ZK_OSCILLATOR.md` — C¹+L¹ timing behavior
- `docs/GOD_PROMPT_ARCHITECTURE.md` — 5-layer overview

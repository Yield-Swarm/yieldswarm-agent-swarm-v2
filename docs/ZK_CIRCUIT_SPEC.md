# ZK Circuit Specification — Entropy Proof (Tasks 1-4, 9, 31)

## Overview

The `entropy_proof` circuit proves knowledge of valid hardware telemetry that hashes to a public `entropySeed` via Poseidon, without revealing raw telemetry values.

## Five-layer mapping

| Layer | Circuit responsibility |
|-------|------------------------|
| **D¹** | Range constraints reject malformed inputs at constraint level |
| **E¹** | Supports rolling-window aggregated inputs off-chain |
| **C¹+L¹** | `nonce` binds proof to rhythmic window batch |
| **ZK¹** | Poseidon hash + Groth16 soundness |
| **PDs¹** | Public seed drives NFT mutation co-evolution |

## Public signals

| Signal | Type | Description |
|--------|------|-------------|
| `entropySeed` | field | Poseidon hash of private telemetry vector |

## Private signals

| Signal | Range | Unit |
|--------|-------|------|
| `gpuTempScaled` | 0..100 | °C integer |
| `vramScaled` | 0..100 | percent |
| `powerScaled` | 0..600 | watts |
| `inferenceTpsScaled` | 0..200 | tokens/sec |
| `packetLossScaled` | 0..100 | percent |
| `tokenId` | field | NFT tokenId salt |
| `nonce` | field | rolling window nonce |
| `nodeProfile` | 0..2 | 0=RTX5090, 1=H100, 2=other |

## Constraints (D¹ Tasks 3-4)

Each private input passes `LessThan(max+1)` — out-of-range witnesses cannot satisfy the R1CS.

## Hash function

```
entropySeed = Poseidon([
  gpuTempScaled, vramScaled, powerScaled,
  inferenceTpsScaled, packetLossScaled,
  tokenId, nonce, nodeProfile
])
```

## Artifacts

| File | Purpose |
|------|---------|
| `circuits/entropy_proof.circom` | Source |
| `circuits/artifacts/entropy_proof.r1cs` | Compiled constraints |
| `circuits/artifacts/entropy_proof_js/entropy_proof.wasm` | Witness generator |
| `circuits/artifacts/entropy_proof_final.zkey` | Proving key |
| `circuits/artifacts/verification_key.json` | Verification key |
| `contracts/verifiers/EntropyProofVerifier.generated.sol` | On-chain verifier (export) |

## Build

```bash
cd circuits && npm install && npm run full-build
```

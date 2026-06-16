#!/usr/bin/env bash
# Export Groth16 Solidity verifier from final zkey (mainnet deployment).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZKEY="$ROOT/circuits/build/entropy_proof_final.zkey"
OUT="$ROOT/contracts/verifiers/EntropyProofGroth16Verifier.sol"

if [[ ! -f "$ZKEY" ]]; then
  echo "Run scripts/zk-trusted-setup.sh first"
  exit 1
fi

npx snarkjs zkey export solidityverifier "$ZKEY" "$OUT"
echo "Exported verifier to $OUT"

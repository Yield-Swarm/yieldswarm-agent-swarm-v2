#!/usr/bin/env bash
# Export Solidity Groth16 verifier (ZK¹ Task 34)
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZKEY="${ROOT}/artifacts/entropy_proof_final.zkey"
OUT="${ROOT}/../contracts/verifiers/EntropyProofVerifier.generated.sol"

if [[ ! -f "$ZKEY" ]]; then
  echo "Run npm run setup first" >&2
  exit 1
fi

npx snarkjs zkey export solidityverifier "$ZKEY" "$OUT"
echo "==> Verifier exported to contracts/verifiers/EntropyProofVerifier.generated.sol"
echo "    Copy/rename to EntropyProofVerifier.sol or inherit in wrapper."

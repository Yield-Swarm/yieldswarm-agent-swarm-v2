#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

R1CS="build/entropy_proof.r1cs"
PTAU="build/pot14_final.ptau"
ZKEY_0="build/entropy_proof_0000.zkey"
ZKEY_FINAL="build/entropy_proof_final.zkey"
VKEY="build/verification_key.json"

if [[ ! -f "$R1CS" ]]; then
  echo "Missing $R1CS — run npm run compile first" >&2
  exit 1
fi

if [[ ! -f "$PTAU" ]]; then
  echo "Downloading powers-of-tau (pot14)..."
  curl -fsSL \
    https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_14.ptau \
    -o "$PTAU"
fi

npx snarkjs groth16 setup "$R1CS" "$PTAU" "$ZKEY_0"
npx snarkjs zkey contribute "$ZKEY_0" "$ZKEY_FINAL" \
  --name="yieldswarm-entropy" -e="yieldswarm entropy trusted setup"
npx snarkjs zkey export verificationkey "$ZKEY_FINAL" "$VKEY"

echo "Trusted setup complete → $ZKEY_FINAL"

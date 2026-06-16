#!/usr/bin/env bash
# Trusted setup: Powers of Tau + circuit-specific phase (ZK¹ Task 32-33)
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PTAU="${ROOT}/artifacts/pot14_final.ptau"
ZKEY="${ROOT}/artifacts/entropy_proof_final.zkey"
VKEY="${ROOT}/artifacts/verification_key.json"
R1CS="${ROOT}/artifacts/entropy_proof.r1cs"

mkdir -p "${ROOT}/artifacts"

if [[ ! -f "$R1CS" ]]; then
  echo "Run npm run compile first" >&2
  exit 1
fi

if [[ ! -f "$PTAU" ]]; then
  echo "==> Downloading Powers of Tau (phase 1)"
  curl -fsSL -o "$PTAU" \
    https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_14.ptau
fi

echo "==> Phase 2 — circuit-specific setup"
npx snarkjs groth16 setup "$R1CS" "$PTAU" "${ROOT}/artifacts/entropy_proof_0000.zkey"

echo "==> Contributing randomness (local dev — use MPC ceremony for production)"
npx snarkjs zkey contribute "${ROOT}/artifacts/entropy_proof_0000.zkey" "$ZKEY" \
  --name="yieldswarm-local" -v -e="$(head -c 32 /dev/urandom | xxd -p)"

echo "==> Export verification key"
npx snarkjs zkey export verificationkey "$ZKEY" "$VKEY"

echo "==> Setup complete: $ZKEY"

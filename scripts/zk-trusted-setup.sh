#!/usr/bin/env bash
# =============================================================================
# scripts/zk-trusted-setup.sh — ZK¹ trusted setup for entropy_proof.circom
#
# Produces:
#   circuits/build/entropy_proof_js/entropy_proof.wasm
#   circuits/build/entropy_proof_final.zkey
#   circuits/build/verification_key.json
#   contracts/verifiers/EntropyProofGroth16Verifier.sol (via zk-export-verifier.sh)
#
# Requirements: circom, snarkjs (npm install in circuits/)
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CIRCUITS="$ROOT/circuits"
BUILD="$CIRCUITS/build"
PTAU="$BUILD/pot14_final.ptau"

mkdir -p "$BUILD"

if ! command -v circom >/dev/null 2>&1; then
  echo "[zk-setup] circom not found — install via: cd circuits && npm install"
  if [[ -d "$CIRCUITS/node_modules/.bin" ]]; then
    export PATH="$CIRCUITS/node_modules/.bin:$PATH"
  else
    exit 1
  fi
fi

if [[ ! -f "$PTAU" ]]; then
  echo "[zk-setup] downloading powers of tau (pot14)..."
  curl -fsSL -o "$BUILD/pot14_0000.ptau" \
    https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_14.ptau
  cp "$BUILD/pot14_0000.ptau" "$PTAU"
fi

echo "[zk-setup] compiling entropy_proof.circom..."
cd "$CIRCUITS"
npx circom entropy_proof.circom --r1cs --wasm --sym -o build -l node_modules 2>/dev/null \
  || circom entropy_proof.circom --r1cs --wasm --sym -o build -l node_modules

echo "[zk-setup] groth16 setup..."
npx snarkjs groth16 setup build/entropy_proof.r1cs "$PTAU" build/entropy_proof_0000.zkey
npx snarkjs zkey contribute build/entropy_proof_0000.zkey build/entropy_proof_final.zkey \
  --name="yieldswarm-entropy" -e="yieldswarm-$(date +%s)" -v

npx snarkjs zkey export verificationkey build/entropy_proof_final.zkey build/verification_key.json

echo "[zk-setup] complete — artifacts in circuits/build/"
echo "[zk-setup] run scripts/zk-export-verifier.sh to export Solidity verifier"

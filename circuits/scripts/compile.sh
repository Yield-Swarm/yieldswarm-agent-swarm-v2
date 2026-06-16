#!/usr/bin/env bash
# Compile entropy_proof.circom → R1CS + WASM (ZK¹ Tasks 31-32)
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="${ROOT}/build"
ARTIFACTS="${ROOT}/artifacts"

mkdir -p "$BUILD_DIR" "$ARTIFACTS"

if ! command -v circom >/dev/null 2>&1; then
  echo "ERROR: circom not installed. Run: npm install && npx circom --version" >&2
  exit 1
fi

echo "==> Compiling entropy_proof.circom"
circom entropy_proof.circom \
  --r1cs --wasm --sym \
  -o "$BUILD_DIR" \
  -l node_modules

cp "$BUILD_DIR/entropy_proof.r1cs" "$ARTIFACTS/entropy_proof.r1cs"
cp -r "$BUILD_DIR/entropy_proof_js" "$ARTIFACTS/entropy_proof_js"

echo "==> Artifacts written to circuits/artifacts/"
ls -la "$ARTIFACTS"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v circom >/dev/null 2>&1; then
  echo "circom not found. Install: https://docs.circom.io/getting-started/installation/" >&2
  exit 1
fi

npm install --no-fund --no-audit

mkdir -p build

circom entropy_proof.circom \
  --r1cs \
  --wasm \
  --sym \
  -l node_modules \
  -o build

echo "Compiled entropy_proof → build/entropy_proof.r1cs + build/entropy_proof_js/"

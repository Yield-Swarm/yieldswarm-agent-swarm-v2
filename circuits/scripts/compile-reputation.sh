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

circom reputation_score.circom \
  --r1cs \
  --wasm \
  --sym \
  -l node_modules \
  -o build

echo "Compiled reputation_score → build/reputation_score.r1cs + build/reputation_score_js/"

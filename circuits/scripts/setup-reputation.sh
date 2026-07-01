#!/usr/bin/env bash
# Trusted setup for reputation_score circuit (dev/local — use production ceremony for mainnet).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/build"

R1CS="reputation_score.r1cs"
PTAU="${PTAU:-powersOfTau28_hez_final_12.ptau}"
ZKEY_0="reputation_score_0000.zkey"
ZKEY_FINAL="reputation_score_final.zkey"

if [[ ! -f "$R1CS" ]]; then
  echo "Missing $R1CS — run: npm run compile:reputation" >&2
  exit 1
fi

if [[ ! -f "$PTAU" ]]; then
  echo "Missing $PTAU — download from snarkjs powersOfTau or set PTAU=..." >&2
  exit 1
fi

npx snarkjs groth16 setup "$R1CS" "$PTAU" "$ZKEY_0"
npx snarkjs zkey contribute "$ZKEY_0" "$ZKEY_FINAL" --name="YieldSwarm ZKML Arena" -v -e="dev-contribution"
npx snarkjs zkey export verificationkey "$ZKEY_FINAL" reputation_verification_key.json

echo "Reputation circuit setup complete → $ZKEY_FINAL"

#!/usr/bin/env bash
# Clean npm environment after hard reset (Termux / Azure).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

echo "[remediate] cleaning node_modules in ${REPO_ROOT}"
rm -rf node_modules

if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi

echo "[remediate] installing tsx for swarm mainnet runner"
npm install --save-dev tsx

echo "[remediate] optional backend deps"
if [[ -f backend/package.json ]]; then
  (cd backend && npm install) || true
fi

echo "[remediate] verify swarm scripts"
npm run | grep -E 'swarm:|run-all-onchain' || true
echo "[remediate] done — run: npm run swarm:mainnet"

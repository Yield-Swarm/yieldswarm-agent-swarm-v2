#!/usr/bin/env bash
# DePIN / IoTeX / geominer smoke test — run after backend is up.
set -euo pipefail

BASE="${1:-http://127.0.0.1:8080}"
EMAIL="${2:-ethyswarm@proton.me}"

step() { printf '\n==> %s\n' "$*"; }

step "healthz"
curl -sf "${BASE}/healthz" | head -c 500
echo

step "consensus 100 rounds"
curl -sf "${BASE}/api/depin/consensus?rounds=100" | head -c 500
echo

step "sync miner profile"
curl -sf -X POST "${BASE}/api/sync" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${EMAIL}\",\"plan\":\"Lite\",\"currentBalance\":1000,\"geomines\":0,\"geodrops\":0,\"surveys\":0}"

echo
step "checklist"
curl -sf "${BASE}/api/depin/checklist?email=${EMAIL}" | head -c 800
echo

step "iotex status"
curl -sf "${BASE}/api/iotex/status" | head -c 400
echo

step "DONE — DePIN smoke passed"

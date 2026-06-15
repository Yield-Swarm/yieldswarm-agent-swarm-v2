#!/usr/bin/env bash
# YieldSwarm stack health checks with optional wait loop.
#
# Usage:
#   ./scripts/health-check.sh --env production
#   ./scripts/health-check.sh --url https://api.yieldswarm.crypto --wait 120

set -euo pipefail

ENV="${HEALTH_ENV:-development}"
BASE_URL=""
WAIT_SECONDS=0
CHECK_INTERVAL=10

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; FAILED=1; }

FAILED=0

default_urls() {
  case "$ENV" in
    MAINNET|production)
      BASE_URL="${BASE_URL:-https://api.yieldswarm.crypto}"
      ;;
    testnet)
      BASE_URL="${BASE_URL:-https://api-testnet.yieldswarm.crypto}"
      ;;
    *)
      BASE_URL="${BASE_URL:-http://localhost:3000}"
      ;;
  esac
}

check_endpoint() {
  local name="$1"
  local url="$2"
  local expected="${3:-200}"

  local status
  status=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")

  if [[ "$status" == "$expected" ]]; then
    pass "$name ($url) → $status"
  else
    fail "$name ($url) → $status (expected $expected)"
  fi
}

run_checks() {
  default_urls

  check_endpoint "API Gateway"        "$BASE_URL/health"
  check_endpoint "Odysseus"           "$BASE_URL/api/v1/odysseus/health"
  check_endpoint "Kairo Identity"     "$BASE_URL/api/v1/kairo/health"
  check_endpoint "Payments"           "$BASE_URL/api/v1/payments/health"
  check_endpoint "ChromaDB (proxy)"   "$BASE_URL/api/v1/odysseus/memory/health"
  check_endpoint "Mandelbrot Ingest"  "$BASE_URL/api/v1/mandelbrot/health"

  if [[ "$FAILED" -eq 0 ]]; then
    pass "All health checks passed"
    return 0
  fi
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)  ENV="$2"; shift 2 ;;
    --url)  BASE_URL="$2"; shift 2 ;;
    --wait) WAIT_SECONDS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ "$WAIT_SECONDS" -gt 0 ]]; then
  elapsed=0
  while [[ $elapsed -lt $WAIT_SECONDS ]]; do
  FAILED=0
    if run_checks; then exit 0; fi
    sleep "$CHECK_INTERVAL"
    elapsed=$((elapsed + CHECK_INTERVAL))
    echo "  Retrying... (${elapsed}s / ${WAIT_SECONDS}s)"
  done
  exit 1
else
  run_checks
fi

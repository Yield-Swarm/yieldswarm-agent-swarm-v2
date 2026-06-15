#!/usr/bin/env bash
# YieldSwarm integration smoke test — run from repo root after deploy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8080}"
KAIRO_URL="${KAIRO_URL:-http://127.0.0.1:8091}"
PASS=0
FAIL=0

check() {
  local name="$1"
  local url="$2"
  if curl -fsS "$url" >/dev/null; then
    echo "[ok] $name — $url"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $name — $url"
    FAIL=$((FAIL + 1))
  fi
}

echo "==> YieldSwarm smoke test"
echo "    BACKEND_URL=$BACKEND_URL"
echo "    KAIRO_URL=$KAIRO_URL"
echo

check "backend health" "$BACKEND_URL/api/health"
check "arena overview" "$BACKEND_URL/api/arena/overview"
check "akash telemetry shim" "$BACKEND_URL/api/telemetry/akash"
check "odysseus telemetry shim" "$BACKEND_URL/api/telemetry/odysseus"
check "vault telemetry" "$BACKEND_URL/api/vault/telemetry"
check "kairo health" "$BACKEND_URL/api/kairo/health"

if curl -fsS "$KAIRO_URL/healthz" >/dev/null 2>&1; then
  check "kairo api direct" "$KAIRO_URL/healthz"
else
  echo "[skip] kairo api direct — not running on $KAIRO_URL"
fi

if command -v python3 >/dev/null; then
  if python3 -m unittest tests.test_kairo_identity -q 2>/dev/null; then
    echo "[ok] kairo identity unit tests"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] kairo identity unit tests"
    FAIL=$((FAIL + 1))
  fi
fi

if command -v node >/dev/null && [ -d backend ]; then
  if (cd backend && npm test --silent 2>/dev/null); then
    echo "[ok] backend unit tests"
    PASS=$((PASS + 1))
  else
    echo "[skip] backend unit tests — run: cd backend && npm test"
  fi
fi

echo
echo "==> Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

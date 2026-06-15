#!/usr/bin/env bash
# YieldSwarm + Kairo integration smoke tests (structural + optional runtime).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $desc"
    FAIL=$((FAIL + 1))
  fi
}

check_file() { [[ -f "$1" ]]; }

echo "=== Structural checks ==="
check_file "DEPLOY.md" && check "DEPLOY.md exists" check_file DEPLOY.md
check_file "DOMAINS.md" && check "DOMAINS.md exists" check_file DOMAINS.md
check_file "MERGE_STRATEGY.md" && check "MERGE_STRATEGY.md exists" check_file MERGE_STRATEGY.md
check_file "INTEGRATION_REPORT.md" && check "INTEGRATION_REPORT.md exists" check_file INTEGRATION_REPORT.md
check_file "KAIRO_FRONTEND.md" && check "KAIRO_FRONTEND.md exists" check_file KAIRO_FRONTEND.md
check "Akash monolith SDL" check_file deploy/deploy-swarm-monolith.yaml
check "Vault bootstrap" check_file vault/setup/bootstrap.sh
check "Vault env loader" check_file scripts/lib/vault-env.sh
check "Kairo identity module" check_file kairo/backend/identity.py
check "Kairo frontend App" check_file kairo/frontend/src/App.tsx
check "Payment kairo fees" check_file src/lib/kairo/fees.ts
check "Stripe deposit route" check_file src/app/api/deposits/stripe/route.ts
check "Stripe webhook route" check_file src/app/api/webhooks/stripe/route.ts
check "Arena page (Next.js)" check_file src/app/arena/page.tsx
check "Platform fee module" check_file src/lib/payments/fees.ts
check "deploy-to-akash.sh" test -x scripts/deploy-to-akash.sh
check "Arena telemetry routes" grep -q telemetry/akash backend/src/routes/api.js
check "Odysseus memory" check_file agents/odysseus_memory.py
check "Sovereign dashboard" check_file dashboard/sovereign-dashboard.html
check "Emission router contract" check_file contracts/GreatDeltaEmissionRouter.sol
check "Merge to main script" check_file scripts/merge-to-main.sh

echo ""
echo "=== Python syntax checks ==="
if command -v python3 >/dev/null 2>&1; then
  for f in kairo/backend/identity.py kairo/backend/mandelbrot.py kairo/backend/telemetry.py; do
    check "Python syntax: $f" python3 -m py_compile "$f"
  done
else
  echo "[SKIP] python3 not available"
fi

echo ""
echo "=== Optional runtime checks ==="
if curl -sf http://127.0.0.1:8100/health >/dev/null 2>&1; then
  check "Kairo API health" curl -sf http://127.0.0.1:8100/health
else
  echo "[SKIP] Kairo API not running on :8100"
fi

if curl -sf http://127.0.0.1:8080/api/health >/dev/null 2>&1; then
  check "Backend API health" curl -sf http://127.0.0.1:8080/api/health
  check "Sovereign state API" curl -sf http://127.0.0.1:8080/api/sovereign/state
  if curl -sf http://127.0.0.1:8080/api/telemetry/odysseus | grep -q '"agents"'; then
    echo "[PASS] Odysseus telemetry returns agents"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] Odysseus telemetry returns agents"
    FAIL=$((FAIL + 1))
  fi
else
  echo "[SKIP] Backend API not running on :8080"
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]

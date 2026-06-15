#!/usr/bin/env bash
# Integration smoke tests across YieldSwarm + Kairo + Odysseus stack.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== YieldSwarm + Kairo Smoke Tests ==="

# File structure
check "deploy-swarm-monolith.yaml exists" test -f deploy/deploy-swarm-monolith.yaml
check "akash-deploy.sh executable" test -x scripts/akash-deploy.sh
check "deploy-to-akash.sh executable" test -x scripts/deploy-to-akash.sh
check "DOMAINS.md exists" test -f DOMAINS.md
check "MERGE_STRATEGY.md exists" test -f MERGE_STRATEGY.md
check "Vault policies exist" test -f vault/policies/kairo-runtime.hcl
check "Kairo identity module" test -f kairo/models/identity.py
check "Odysseus service" test -f services/odysseus/main.py
check "Emission router contract" test -f contracts/GreatDeltaEmissionRouter.sol
check "Sovereign dashboard" test -f dashboard/sovereign-dashboard.html
check "Payment rails page" test -f src/app/payments/page.tsx
check "Arena page (Next.js)" test -f src/app/arena/page.tsx
check "Stripe deposit route" test -f src/app/api/deposits/stripe/route.ts
check "Stripe webhook route" test -f src/app/api/webhooks/stripe/route.ts
check "Platform fee module" test -f src/lib/payments/fees.ts

# Python imports
check "Kairo tests" python3 -m pytest kairo/tests/ -q
check "Odysseus memory tests" python3 -m pytest tests/test_odysseus_memory.py -q
check "YieldSwarm tools tests" python3 -m pytest tests/test_yieldswarm_tools.py -q

# Node unit tests (payments, ledger, auth)
if command -v npm >/dev/null 2>&1 && [[ -d node_modules ]]; then
  check "Vitest (src/lib)" npm test
fi

# Frontend shared-module tests (node:test)
check "Frontend auth/telemetry" node --test frontend/tests/*.test.js

# Secrets audit — no hardcoded API keys in tracked files
if rg -l 'ud_mcp_[a-f0-9]{20,}' --glob '!*.lock' . 2>/dev/null; then
  echo "  ✗ hardcoded UD API key found"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ no hardcoded UD API keys"
  PASS=$((PASS + 1))
fi

# HTTP health (if services running)
if curl -sf http://localhost:8787/healthz >/dev/null 2>&1; then
  check "Kairo API health" curl -sf http://localhost:8787/healthz
fi
if curl -sf http://localhost:8080/healthz >/dev/null 2>&1; then
  check "Odysseus health" curl -sf http://localhost:8080/healthz
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1

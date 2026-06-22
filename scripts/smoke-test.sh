#!/usr/bin/env bash
# YieldSwarm integration smoke test — structural checks + optional runtime probes.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8080}"
KAIRO_URL="${KAIRO_URL:-http://127.0.0.1:8100}"
PASS=0
FAIL=0

check_cmd() {
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

check_url() {
  local name="$1"
  local url="$2"
  if curl -fsS "$url" >/dev/null 2>&1; then
    echo "  ✓ $name — $url"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name — $url"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== YieldSwarm + Kairo Smoke Tests ==="

# File structure
check_cmd "deploy-swarm-monolith.yaml exists" test -f deploy/deploy-swarm-monolith.yaml
check_cmd "akash-deploy.sh executable" test -x scripts/akash-deploy.sh
check_cmd "deploy-to-akash.sh executable" test -x scripts/deploy-to-akash.sh
check_cmd "DOMAINS.md exists" test -f DOMAINS.md
check_cmd "MERGE_STRATEGY.md exists" test -f MERGE_STRATEGY.md
check_cmd "Vault policies exist" test -f vault/policies/kairo-runtime.hcl
check_cmd "Kairo identity module" test -f kairo/models/identity.py
check_cmd "Odysseus service" test -f services/odysseus/main.py
check_cmd "Emission router contract" test -f contracts/GreatDeltaEmissionRouter.sol
check_cmd "Sovereign dashboard" test -f dashboard/sovereign-dashboard.html
check_cmd "Payment rails page" test -f src/app/payments/page.tsx
check_cmd "Arena page (Next.js)" test -f src/app/arena/page.tsx
check_cmd "Stripe deposit route" test -f src/app/api/deposits/stripe/route.ts
check_cmd "Stripe webhook route" test -f src/app/api/webhooks/stripe/route.ts
check_cmd "Platform fee module" test -f src/lib/payments/fees.ts
check_cmd "Integration backend" test -f backend/src/server.js
check_cmd "Rewards orchestrator" test -f services/rewards/orchestrator.py
check_cmd "Rewards sweep script" test -x scripts/rewards/sweep-rewards.sh
check_cmd "Helix Nodes service" test -f services/helix_nodes/store.py
check_cmd "Helix Node extension" test -f extensions/helix-node/manifest.json
check_cmd "Marketing vault policy" test -f vault/policies/marketing-runtime.hcl
check_cmd "Marketing health route" test -f src/app/api/integrations/marketing/health/route.ts
check_cmd "MarketingService" test -f src/lib/marketing/marketingService.ts

# Python tests
check_cmd "Kairo tests" python3 -m pytest kairo/tests/ -q
check_cmd "Odysseus memory tests" python3 -m pytest tests/test_odysseus_memory.py -q
check_cmd "YieldSwarm tools tests" python3 -m pytest tests/test_yieldswarm_tools.py -q

# Node unit tests
if command -v npm >/dev/null 2>&1 && [[ -d node_modules ]]; then
  check_cmd "Vitest (src/lib)" npm run test:unit
  check_cmd "Backend unit tests" npm run test:backend
fi

check_cmd "Frontend auth/telemetry" node --test frontend/tests/*.test.js

# Secrets audit
if rg -l 'ud_mcp_[a-f0-9]{20,}' --glob '!*.lock' . 2>/dev/null; then
  echo "  ✗ hardcoded UD API key found"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ no hardcoded UD API keys"
  PASS=$((PASS + 1))
fi

echo ""
echo "=== Optional runtime checks ==="
if curl -sf "$KAIRO_URL/health" >/dev/null 2>&1 || curl -sf "$KAIRO_URL/healthz" >/dev/null 2>&1; then
  check_url "Kairo API health" "$KAIRO_URL/health"
else
  echo "  [skip] Kairo API not running on $KAIRO_URL"
fi

if curl -sf "$BACKEND_URL/api/health" >/dev/null 2>&1; then
  check_url "Backend API health" "$BACKEND_URL/api/health"
  check_url "Sovereign state API" "$BACKEND_URL/api/sovereign/state"
else
  echo "  [skip] Backend API not running on $BACKEND_URL"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1

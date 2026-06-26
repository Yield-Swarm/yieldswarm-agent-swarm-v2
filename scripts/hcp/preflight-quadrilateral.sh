#!/usr/bin/env bash
# HCP quadrilateral preflight — verify yield-swarm-org resources and CLI tooling.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${REPO_ROOT}/infra/hcp/quadrilateral-manifest.json"

echo "=== HCP Quadrilateral Preflight ==="
echo "Org:     yield-swarm-org"
echo "Project: YieldSwarmHasiCorp (331458d4-6c74-4e95-9497-cf2d6b846f31)"
echo "Budget:  ~\$500 promotional credit"
echo ""

pass=0
warn=0
fail=0

check_cli() {
  local cmd="$1"
  local required="${2:-yes}"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  ok   $cmd"
    pass=$((pass + 1))
  elif [[ "$required" == "yes" ]]; then
    echo "  MISS $cmd (required)"
    fail=$((fail + 1))
  else
    echo "  skip $cmd (optional)"
    warn=$((warn + 1))
  fi
}

echo "--- CLI tooling ---"
check_cli hcp yes
check_cli vault yes
check_cli terraform yes
check_cli packer no
check_cli boundary no

echo ""
echo "--- Environment ---"
for var in HCP_ORGANIZATION HCP_PROJECT HCP_PROJECT_ID VAULT_ADDR; do
  if [[ -n "${!var:-}" ]]; then
    echo "  ok   $var set"
    pass=$((pass + 1))
  else
    echo "  hint $var unset (see docs/HCP_ORGANIZATION.md)"
    warn=$((warn + 1))
  fi
done

echo ""
echo "--- Quadrilateral manifest ---"
if [[ -f "$MANIFEST" ]]; then
  python3 - <<PY
import json
from pathlib import Path
m = json.loads(Path("$MANIFEST").read_text())
q = m["quadrilateral"]
print(f"  vault:    {q['vault']['resourceName']} ({q['vault']['region']})")
print(f"  boundary: {q['boundary']['resourceName']} ({q['boundary']['region']})")
print(f"  hvn:      {q['hvn']['primary']['resourceName']} + {q['hvn']['failover']['resourceName']}")
print(f"  packer:   {q['packer']['imageName']}")
print(f"  tracks:   A={q['vault']['parallelTrack']} B={q['boundary']['parallelTrack']} C={q['packer']['parallelTrack']} D={q['terraform']['parallelTrack']}")
PY
  pass=$((pass + 1))
else
  echo "  MISS quadrilateral-manifest.json"
  fail=$((fail + 1))
fi

echo ""
echo "--- HCP API (if authenticated) ---"
if command -v hcp >/dev/null 2>&1 && hcp auth print-access-token >/dev/null 2>&1; then
  echo "  ok   hcp authenticated"
  pass=$((pass + 1))
  if hcp projects list 2>/dev/null | grep -q "YieldSwarmHasiCorp"; then
    echo "  ok   YieldSwarmHasiCorp project visible"
    pass=$((pass + 1))
  else
    echo "  warn YieldSwarmHasiCorp not found in hcp projects list"
    warn=$((warn + 1))
  fi
else
  echo "  hint run: hcp auth login"
  warn=$((warn + 1))
fi

echo ""
echo "--- Vault reachability ---"
if [[ -n "${VAULT_ADDR:-}" ]] && command -v vault >/dev/null 2>&1; then
  if vault status >/dev/null 2>&1; then
    echo "  ok   vault reachable at $VAULT_ADDR"
    pass=$((pass + 1))
  else
    echo "  warn vault not reachable (sealed or token missing)"
    warn=$((warn + 1))
  fi
else
  echo "  skip vault check (VAULT_ADDR unset)"
  warn=$((warn + 1))
fi

echo ""
echo "=== Preflight complete: $pass passed, $warn warnings, $fail failures ==="
[[ "$fail" -eq 0 ]]

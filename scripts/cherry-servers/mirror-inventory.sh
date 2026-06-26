#!/usr/bin/env bash
# Cherry Servers 90-day funding mirror — repo + cloud inventory (ls -la style)
#
# Usage:
#   ./scripts/cherry-servers/mirror-inventory.sh
#   ./scripts/cherry-servers/mirror-inventory.sh --export-specs
#
# Output:
#   .run/cherry-mirror-inventory.txt
#   .run/cherry-servers-cloud-specs.json (with --export-specs)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
mkdir -p .run reports

OUT="${ROOT}/.run/cherry-mirror-inventory.txt"
EXPORT_SPECS=0
[[ "${1:-}" == "--export-specs" ]] && EXPORT_SPECS=1

{
  echo "================================================================"
  echo "Cherry Servers Mirror Inventory — YieldSwarm Agent Swarm v2"
  echo "Generated: $(date -u)"
  echo "Purpose: 90-day Cherry Servers funding packet mirror"
  echo "================================================================"
  echo ""

  echo "## Repository root (ls -la)"
  ls -la "${ROOT}"
  echo ""

  for dir in scripts deploy config/helix config/multicloud backend akash deploy/azure scripts/cherry-servers scripts/gpu-pool scripts/termux; do
    if [[ -d "${ROOT}/${dir}" ]]; then
      echo "## ${dir}/ (ls -la)"
      ls -la "${ROOT}/${dir}"
      echo ""
    fi
  done

  echo "## GPU pool config"
  if [[ -f deploy/env/gpu-pool.env ]]; then
    grep -vE 'KEY=|TOKEN=|SECRET=' deploy/env/gpu-pool.env || true
  else
    cat deploy/env/gpu-pool.env.example 2>/dev/null || echo "(no gpu-pool env)"
  fi
  echo ""

  echo "## Multicloud budgets"
  cat config/multicloud/budgets.env.example 2>/dev/null || true
  echo ""

  echo "## Active Akash / GPU pool state"
  for f in .run/gpu-pool-allocation.json .run/akash-deploy.json .run/akash-lease.env .run/cherry-servers-cloud-specs.json; do
    if [[ -f "${ROOT}/${f}" ]]; then
      echo "### ${f}"
      cat "${ROOT}/${f}"
      echo ""
    fi
  done

  echo "## Termux / edge deploy scripts"
  ls -la "${ROOT}/scripts/termux/" 2>/dev/null || true
  echo ""

  echo "================================================================"
  echo "End mirror — attach this file + cherry-servers-cloud-specs to Cherry packet"
  echo "================================================================"
} | tee "$OUT"

echo "[cherry-mirror] Wrote ${OUT}"

if [[ "$EXPORT_SPECS" -eq 1 && -x scripts/cherry-servers/export-cloud-specs.sh ]]; then
  bash scripts/cherry-servers/export-cloud-specs.sh
  echo "[cherry-mirror] Also ran export-cloud-specs.sh"
fi

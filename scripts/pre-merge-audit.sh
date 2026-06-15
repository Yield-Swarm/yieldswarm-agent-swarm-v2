#!/usr/bin/env bash
# Pre-merge validation per MERGE_STRATEGY.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Secret scan"
bash scripts/secrets-audit.sh

echo "==> Required docs"
for f in MERGE_STRATEGY.md DEPLOY.md DOMAINS.md INTEGRATION_REPORT.md; do
  [ -f "$f" ] || { echo "MISSING: $f"; exit 1; }
  echo "  ok $f"
done

echo "==> Python smoke"
python3 kairo/cli.py ping

echo "==> Backend tests"
(cd backend && npm test --silent)

echo "OK: pre-merge audit passed"

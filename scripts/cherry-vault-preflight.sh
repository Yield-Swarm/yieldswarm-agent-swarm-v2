#!/usr/bin/env bash
# Verify Cherry Servers API key resolves from Vault (never from repo).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 <<'PY'
import sys

sys.path.insert(0, ".")
from services.infra.cherry_client import check_cherry_api

result = check_cherry_api()
print(f"Cherry API key (masked): {result.api_key_mask}")
print(f"Latency: {result.latency_ms:.0f}ms  Teams: {result.team_count}")
if not result.ok:
    print(f"FAIL: {result.error}", file=sys.stderr)
    raise SystemExit(1)
print("Cherry Servers Vault integration OK")
PY

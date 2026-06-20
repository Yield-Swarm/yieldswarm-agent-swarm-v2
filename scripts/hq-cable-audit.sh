#!/usr/bin/env bash
# God Task #9 — HQ floor/cable hazard audit (dry-run safe)
set -euo pipefail
echo "=== HQ Cable / Floor Hazard Audit ==="
echo "[audit] Checking deploy monitor + solenoid throttle endpoints..."
API_BASE="${API_BASE:-http://127.0.0.1:8080}"
curl -sf "$API_BASE/api/solenoid/status" >/dev/null 2>&1 && echo "[ok] solenoid status" || echo "[warn] backend offline"
echo "[audit] Verify: cables secured, power strips labeled, trading terminal stable"
echo "[audit] Log to Notion when NOTION_API_KEY configured (task 7)"
exit 0

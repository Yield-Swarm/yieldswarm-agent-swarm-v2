#!/usr/bin/env bash
# 4 God Tasks — interwoven with Solenoid branches (edge → vault → w3bstream → WAN)
# Run from repo root after Vault/IoTeX env is set.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
LOG_DIR="${ROOT}/.run/god-tasks"
mkdir -p "${LOG_DIR}"

log() { printf '[god-task] %s\n' "$*"; }

# ---- Task 1: Edge gateway + coordinate normalization ----
log "Task 1/4: Edge gateway normalizer (Solenoid ingest branch)"
python3 - <<'PY' | tee "${LOG_DIR}/task1-edge.log"
import json
from pathlib import Path

def normalize_coords(raw: float) -> float:
    degrees = int(raw // 100)
    minutes = raw - degrees * 100
    return degrees + minutes / 60

payload = {
    "device_identity": "ioID_Pebble_V1",
    "network_edge_source": "192.168.1.158",
    "telemetry": {
        "latitude_dd": round(normalize_coords(3050.69225), 6),
        "longitude_dd": round(normalize_coords(11448.65815), 6),
        "snr": 14.2,
        "vbat": 3700,
    },
}
out = Path("/tmp/normalized_edge_payload.json")
out.write_text(json.dumps(payload, indent=2))
print(json.dumps({"ok": True, "path": str(out), "telemetry": payload["telemetry"]}))
PY

# ---- Task 2: Vault secret paths (dry-run unless VAULT_ADDR set) ----
log "Task 2/4: Vault injection check (Solenoid shadow branch)"
if [[ -n "${VAULT_ADDR:-}" ]]; then
  python3 "${ROOT}/scripts/vault-export-env.py" mining 2>/dev/null | head -5 | tee "${LOG_DIR}/task2-vault.log" || true
else
  echo '{"ok":false,"note":"VAULT_ADDR unset — use make seed-vault"}' | tee "${LOG_DIR}/task2-vault.log"
fi

# ---- Task 3: IoTeX W3bstream ingest probe ----
log "Task 3/4: W3bstream prover path (Solenoid telemetry branch)"
if curl -sf http://127.0.0.1:8080/api/iotex/status >/dev/null 2>&1; then
  curl -sf http://127.0.0.1:8080/api/iotex/status | tee "${LOG_DIR}/task3-iotex.log"
else
  echo '{"live":false,"note":"start backend for /api/iotex/status"}' | tee "${LOG_DIR}/task3-iotex.log"
fi

# ---- Task 4: WAN / consensus + mining hashpower ----
log "Task 4/4: HELIX consensus + fleet hashpower (Solenoid matrix branch)"
node "${ROOT}/scripts/helix-consensus-runner.mjs" 100 | tee "${LOG_DIR}/task4-consensus.log"
python3 -m mining hashpower --json | tee "${LOG_DIR}/task4-hashpower.log"

# Solenoid API matrix if backend live
if curl -sf http://127.0.0.1:8080/api/solenoid/matrix >/dev/null 2>&1; then
  curl -sf -X POST http://127.0.0.1:8080/api/solenoid/matrix \
    -H 'Content-Type: application/json' \
    -d '{"source":"god-task-hotload"}' | tee "${LOG_DIR}/task4-solenoid-matrix.log"
fi

log "All 4 God Tasks complete. Logs: ${LOG_DIR}"

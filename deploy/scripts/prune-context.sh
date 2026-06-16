#!/usr/bin/env bash
# Context pruning hook invoked by entrypoint.monitor.sh on VRAM/temp breach.
set -euo pipefail

PID="${1:?pid}"
REASON="${2:-threshold}"

LOG="${PRUNE_LOG:-.run/context-prune.log}"
mkdir -p "$(dirname "$LOG")"

printf '%s prune pid=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PID" "$REASON" >> "$LOG"

# Signal workload to drop ephemeral context (Odysseus / vLLM handlers should trap SIGUSR1).
if kill -0 "$PID" 2>/dev/null; then
  kill -USR1 "$PID" 2>/dev/null || true
fi

# Optional: invoke Odysseus memory prune API when available.
if [[ -n "${ODYSSEUS_BRAIN_URL:-}" ]]; then
  curl -sf -X POST "${ODYSSEUS_BRAIN_URL}/v1/context/prune" \
    -H 'Content-Type: application/json' \
    -d "{\"reason\":\"${REASON}\",\"pid\":${PID}}" >/dev/null 2>&1 || true
fi

exit 0

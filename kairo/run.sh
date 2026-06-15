#!/usr/bin/env bash
# Start Kairo → YieldSwarm bridge API
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
  .venv/bin/pip install -q -r kairo/requirements.txt
fi

exec .venv/bin/uvicorn kairo.api.main:app --host "${KAIRO_API_HOST:-0.0.0.0}" --port "${KAIRO_API_PORT:-8090}" --reload

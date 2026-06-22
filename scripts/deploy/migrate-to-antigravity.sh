#!/usr/bin/env bash
# scripts/deploy/migrate-to-antigravity.sh
#
# One-command migration from YieldSwarm/antigravity-sdk-python fork → official SDK.
# Idempotent; safe to re-run.
#
# Usage (from repo root):
#   export GEMINI_API_KEY=...
#   ./scripts/deploy/migrate-to-antigravity.sh
#   ./scripts/deploy/migrate-to-antigravity.sh --smoke   # import + policy checks only
#
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SMOKE=0
[[ "${1:-}" == "--smoke" ]] && SMOKE=1

log() { printf '[migrate-antigravity] %s\n' "$*"; }
die() { log "ERROR: $*"; exit 1; }

log "repo: $ROOT"

# ---------------------------------------------------------------------------
# 1. Remove legacy fork packages (no-op if never installed)
# ---------------------------------------------------------------------------
for pkg in antigravity-sdk-python yieldswarm-antigravity antigravity_sdk; do
  if pip show "$pkg" >/dev/null 2>&1; then
    log "uninstalling legacy package: $pkg"
    pip uninstall -y "$pkg" >/dev/null 2>&1 || true
  fi
done

# Also remove editable installs that shadow the official module name
if pip show google-antigravity 2>/dev/null | grep -q 'Location:.*antigravity-sdk-python'; then
  log "removing forked google-antigravity install"
  pip uninstall -y google-antigravity >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 2. Install official SDK from PyPI (includes platform binary wheel)
# ---------------------------------------------------------------------------
log "installing google-antigravity>=0.1.4 from PyPI"
pip install --upgrade 'google-antigravity>=0.1.4' 'protobuf>=4.25,<7'

# ---------------------------------------------------------------------------
# 3. Write runtime config marker
# ---------------------------------------------------------------------------
CONFIG_DIR="$ROOT/config"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/antigravity.json" <<EOF
{
  "runtime": "google-antigravity",
  "sdk_source": "pypi",
  "min_version": "0.1.4",
  "handler": "services/intelligence/antigravity_core.py",
  "auth": {
    "gemini_api_key_env": "GEMINI_API_KEY",
    "vertex_env_flag": "ANTIGRAVITY_VERTEX",
    "gcp_project_env": "GOOGLE_CLOUD_PROJECT",
    "gcp_location_env": "GOOGLE_CLOUD_LOCATION"
  },
  "safety": {
    "block_destructive_shell": true,
    "auto_approve_env": "ANTIGRAVITY_AUTO_APPROVE"
  },
  "migrated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
log "wrote $CONFIG_DIR/antigravity.json"

# ---------------------------------------------------------------------------
# 4. Validate import + YieldSwarm policy wiring
# ---------------------------------------------------------------------------
python3 - <<'PY'
from services.intelligence.antigravity_core import (
    SovereignAntigravityHandler,
    YieldSwarmAntigravityConfig,
    build_yieldswarm_policies,
    is_antigravity_available,
    _is_destructive_command,
)

assert is_antigravity_available(), "google-antigravity import failed"
policies = build_yieldswarm_policies()
assert len(policies) >= 3, "expected safety policies"

assert _is_destructive_command({"CommandLine": "rm -rf /"})
assert not _is_destructive_command({"CommandLine": "ls -la"})

cfg = YieldSwarmAntigravityConfig.from_env()
local = cfg.build_local_config()
assert local.system_instructions, "missing system instructions"

print("import_ok policies=", len(policies))
PY

log "structural validation passed"

if [[ "$SMOKE" -eq 1 ]]; then
  log "smoke mode — skipping live agent call (needs GEMINI_API_KEY)"
  exit 0
fi

if [[ -z "${GEMINI_API_KEY:-}" ]] && [[ "${ANTIGRAVITY_VERTEX:-}" != "1" ]]; then
  log "WARN: GEMINI_API_KEY not set and ANTIGRAVITY_VERTEX!=1 — skip live agent smoke"
  log "Set GEMINI_API_KEY or ANTIGRAVITY_VERTEX=1 + gcloud ADC, then re-run"
  exit 0
fi

# ---------------------------------------------------------------------------
# 5. Optional live smoke (streams GPU health prompt)
# ---------------------------------------------------------------------------
log "running sovereign handler smoke (streaming)..."
python3 -m services.intelligence.antigravity_core "Reply with exactly: ANTIGRAVITY_OK"

log "migration complete"
log "next: git add config/antigravity.json && deploy to Azure VMSS / Akash GPU workers"

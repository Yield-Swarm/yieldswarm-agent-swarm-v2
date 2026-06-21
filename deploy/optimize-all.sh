#!/usr/bin/env bash
# deploy/optimize-all.sh — v1.0 sitemap → production full-stack tune
# Run from repo root (Pixel Termux: cd ~/yieldswarm && bash deploy/optimize-all.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUN_DIR="${RUN_DIR:-.run}"
mkdir -p "$RUN_DIR"

log()  { printf '[optimize] %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
ok()   { log "OK: $*"; }
warn() { log "WARN: $*"; }

# ---------------------------------------------------------------------------
# 1. Git / repo hygiene
# ---------------------------------------------------------------------------
step "Git / repo validate"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
  log "branch=$BRANCH commit=$(git rev-parse --short HEAD)"
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    warn "working tree has uncommitted changes"
  else
    ok "working tree clean"
  fi
else
  warn "not a git repository"
fi

# ---------------------------------------------------------------------------
# 2. Sovereign core status + optional daemon start
# ---------------------------------------------------------------------------
step "Sovereign Core (iteration-100)"
if [[ -f dashboard/state.json ]]; then
  python3 - <<'PY'
import json, pathlib
s = json.loads(pathlib.Path("dashboard/state.json").read_text())
print(f"  vault net worth ${s.get('net_worth_usd',0):,.0f} / ${s.get('vault_target_usd',0):,.0f}")
print(f"  blended APY {s.get('blended_apy',0):.1%}  workers {s.get('counts',{}).get('workers',0)}")
PY
else
  warn "dashboard/state.json missing — run: python3 iteration-100/run.py --ticks 500"
fi

if [[ "${START_SOVEREIGN:-0}" == "1" ]]; then
  if [[ -f deploy/scripts/start-sovereign-loops.sh ]]; then
    bash deploy/scripts/start-sovereign-loops.sh start || warn "sovereign loops start failed"
  fi
  nohup python3 iteration-100/run.py --quiet --target-apy 40 --seed-vault --interval 30 \
    >>"$RUN_DIR/sovereign-core.log" 2>&1 &
  echo $! >"$RUN_DIR/sovereign-core.pid"
  ok "sovereign core daemon pid=$(cat "$RUN_DIR/sovereign-core.pid")"
fi

# ---------------------------------------------------------------------------
# 3. Akash GPU bid tune
# ---------------------------------------------------------------------------
step "Akash GPU bid optimizer"
if [[ -f akash/bid-optimizer.py ]]; then
  python3 akash/bid-optimizer.py --gpu h100 --target-apr 40 --max-bid 85000 --auto \
    | tee "$RUN_DIR/akash-bid-optimize.json" || warn "bid optimizer exited non-zero"
else
  warn "akash/bid-optimizer.py not found"
fi

# ---------------------------------------------------------------------------
# 4. Kairo telemetry + Nexus / Helium bridge
# ---------------------------------------------------------------------------
step "Kairo telemetry daemon"
if [[ -f kairo/telemetry_daemon.py ]]; then
  if [[ "${START_KAIRO_TELEMETRY:-0}" == "1" ]]; then
    nohup python3 kairo/telemetry_daemon.py --helium --nexus --halo2-prove \
      >>"$RUN_DIR/kairo-telemetry.log" 2>&1 &
    echo $! >"$RUN_DIR/kairo-telemetry.pid"
    ok "kairo telemetry pid=$(cat "$RUN_DIR/kairo-telemetry.pid")"
  else
    python3 kairo/telemetry_daemon.py --once --helium --nexus || true
  fi
else
  warn "kairo/telemetry_daemon.py not found"
fi

# ---------------------------------------------------------------------------
# 5. Hardware monitor (heat / VRAM guard)
# ---------------------------------------------------------------------------
step "Global monitor (entrypoint.monitor.sh)"
if [[ -f deploy/entrypoint.monitor.sh ]]; then
  if [[ "${START_MONITOR:-0}" == "1" ]]; then
    nohup bash deploy/entrypoint.monitor.sh >>"${HOME}/monitor.log" 2>&1 &
    echo $! >"$RUN_DIR/monitor.pid"
    ok "monitor pid=$(cat "$RUN_DIR/monitor.pid") log=~/monitor.log"
  else
    log "set START_MONITOR=1 to launch heat guard daemon"
  fi
else
  warn "deploy/entrypoint.monitor.sh missing"
fi

# ---------------------------------------------------------------------------
# 6. Vault / ZK stack smoke
# ---------------------------------------------------------------------------
step "Vault / YSLR / Halo2 wiring"
for f in docs/VAULT_ENV_INJECTION.md docs/ZK_ENTROPY_SETUP.md docs/TREASURY.md; do
  [[ -f "$f" ]] && log "  doc ok: $f" || warn "missing $f"
done
if [[ -f circuits/entropy_proof.circom ]]; then
  ok "Halo2/ZK entropy circuit present"
fi

# ---------------------------------------------------------------------------
# 7. Monitoring stack (Docker required)
# ---------------------------------------------------------------------------
step "Prometheus / Grafana monitoring"
if command -v docker >/dev/null 2>&1 && [[ -f deploy/scripts/start-monitoring.sh ]]; then
  bash deploy/scripts/start-monitoring.sh up || warn "monitoring stack failed"
else
  warn "docker unavailable — skip Prometheus/Grafana (Pixel: use Termux proot or remote host)"
fi

step "Optimize pass complete"
log "Verification:"
log "  git status"
log "  python3 iteration-100/run.py --status"
log "  akash query market lease list  # when akash CLI configured"
log "  tail -f ~/monitor.log          # when START_MONITOR=1"

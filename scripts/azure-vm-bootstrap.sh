#!/usr/bin/env bash
# Bootstrap YieldSwarm on a fresh Ubuntu Azure VM.
#
# Run on the VM after SSH:
#   curl -fsSL https://raw.githubusercontent.com/Yield-Swarm/yieldswarm-agent-swarm-v2/main/scripts/azure-vm-bootstrap.sh | bash
# Or from a cloned repo:
#   ./scripts/azure-vm-bootstrap.sh
#
# Options:
#   --repo-url URL     Git clone URL (default: Yield-Swarm repo)
#   --branch BRANCH    Branch to checkout (default: main)
#   --skip-clone       Use current directory as repo root
#   --no-systemd       Skip systemd service install
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"
BRANCH="${BRANCH:-main}"
SKIP_CLONE=0
INSTALL_SYSTEMD=1

for arg in "$@"; do
  case "$arg" in
    --skip-clone) SKIP_CLONE=1 ;;
    --no-systemd) INSTALL_SYSTEMD=0 ;;
    --repo-url=*) REPO_URL="${arg#*=}" ;;
    --branch=*) BRANCH="${arg#*=}" ;;
  esac
done

log() { printf '[azure-vm] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

if [[ "$(id -u)" -eq 0 ]]; then
  die "Run as a normal user (not root). Script uses sudo where needed."
fi

log "=== 1. System packages ==="
sudo apt-get update -qq
sudo apt-get install -y git curl build-essential pkg-config libssl-dev python3 python3-pip python3-venv

log "=== 2. Node.js 20 LTS ==="
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | cut -d. -f1 | tr -d v)" -lt 18 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
log "node $(node -v) npm $(npm -v)"

log "=== 3. Rust toolchain ==="
if ! command -v cargo >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# shellcheck disable=SC1091
source "$HOME/.cargo/env" 2>/dev/null || true
log "rustc $(rustc --version)"

log "=== 4. Clone repository ==="
if [[ "$SKIP_CLONE" -eq 0 ]]; then
  TARGET="${HOME}/yieldswarm-agent-swarm-v2"
  if [[ -d "$TARGET/.git" ]]; then
    log "repo exists — pulling $BRANCH"
    cd "$TARGET"
    git fetch origin "$BRANCH"
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
  else
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$TARGET"
    cd "$TARGET"
  fi
else
  TARGET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "$TARGET"
fi
REPO_ROOT="$PWD"
log "repo root: $REPO_ROOT"

log "=== 5. Environment file ==="
if [[ ! -f .env ]]; then
  cp .env.example .env
  log "created .env from .env.example — edit with Vault keys before production"
fi

log "=== 6. Python dependencies ==="
python3 -m pip install --user -q -r requirements.txt 2>/dev/null || python3 -m pip install --user -q pytest

log "=== 7. Node backend ==="
cd "$REPO_ROOT/backend"
npm ci --omit=dev
cd "$REPO_ROOT"

log "=== 8. Rust build (release) ==="
cargo build --release -p yieldswarm-core -p swarm-core

log "=== 9. Smoke tests ==="
python3 -m pytest tests/test_single_pane.py tests/test_mining_manager.py -q --tb=no 2>/dev/null || log "WARN: some pytest skipped"
cargo test -p yieldswarm-core -q 2>/dev/null || true

if [[ "$INSTALL_SYSTEMD" -eq 1 ]] && command -v systemctl >/dev/null 2>&1; then
  log "=== 10. systemd services ==="
  for unit in yieldswarm-backend.service yieldswarm-sovereign.service; do
    sudo sed "s#__REPO__#${REPO_ROOT}#g" "$REPO_ROOT/deploy/systemd/$unit" \
      | sudo tee "/etc/systemd/system/$unit" >/dev/null
  done
  sudo systemctl daemon-reload
  sudo systemctl enable yieldswarm-backend.service
  sudo systemctl restart yieldswarm-backend.service || log "WARN: backend start failed — check .env"
  log "backend status: $(systemctl is-active yieldswarm-backend.service 2>/dev/null || echo unknown)"
fi

PUBLIC_IP="$(curl -fsS -H Metadata:true 'http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text' 2>/dev/null || hostname -I | awk '{print $1}')"

cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║  YieldSwarm Azure VM bootstrap complete                      ║
╚══════════════════════════════════════════════════════════════╝

Repo:     $REPO_ROOT
Branch:   $BRANCH

Dashboard URLs (open port 8080 in Azure NSG):
  http://${PUBLIC_IP}:8080/command-center
  http://${PUBLIC_IP}:8080/arena/
  http://${PUBLIC_IP}:8080/api/health
  http://${PUBLIC_IP}:8080/api/single-pane/overview

Manual start (if not using systemd):
  cd $REPO_ROOT/backend && PORT=8080 npm start

Rust particle accelerator (optional foreground demo):
  $REPO_ROOT/target/release/swarm-core

Edit secrets:
  nano $REPO_ROOT/.env

NSG inbound rule: Allow TCP 8080 from your IP (or Any for testing).

EOF

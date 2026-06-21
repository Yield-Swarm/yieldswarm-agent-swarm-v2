#!/usr/bin/env bash
# Pixel / Termux bootstrap — YieldSwarm operator workstation
#
# Usage (Termux on Pixel or Debian proot):
#   curl -fsSL https://raw.githubusercontent.com/Yield-Swarm/yieldswarm-agent-swarm-v2/development/scripts/pixel-termux-bootstrap.sh | bash
#
# Or after clone:
#   ./scripts/pixel-termux-bootstrap.sh
#
# Env:
#   REPO_URL     default: GitHub Yield-Swarm/yieldswarm-agent-swarm-v2
#   BRANCH       default: development
#   INSTALL_DIR  default: ~/yieldswarm
#   SKIP_CLONE=1 skip git clone if repo already present
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"
BRANCH="${BRANCH:-development}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/yieldswarm}"

log() { printf '[pixel-bootstrap] %s\n' "$*"; }

install_packages() {
  if command -v pkg >/dev/null 2>&1; then
    log "Termux: pkg install"
    pkg update -y
    pkg install -y git curl htop tmux unzip python clang make openssl-tool
    return
  fi
  if command -v apt-get >/dev/null 2>&1; then
    log "Debian/Ubuntu: apt install"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl git htop tmux unzip build-essential python3 python3-pip python3-venv nodejs npm
    return
  fi
  log "WARN: unknown package manager — install git curl python3 node manually"
}

clone_repo() {
  mkdir -p "$(dirname "$INSTALL_DIR")"
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "Repo exists at $INSTALL_DIR — pulling $BRANCH"
    git -C "$INSTALL_DIR" fetch origin "$BRANCH"
    git -C "$INSTALL_DIR" checkout "$BRANCH" 2>/dev/null || git -C "$INSTALL_DIR" checkout -B "$BRANCH" "origin/$BRANCH"
    git -C "$INSTALL_DIR" pull origin "$BRANCH" || true
  else
    log "Cloning $REPO_URL -> $INSTALL_DIR (branch $BRANCH)"
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi
}

post_clone() {
  cd "$INSTALL_DIR"
  log "Python deps (Kairo)"
  pip install -q -r kairo/requirements.txt 2>/dev/null || pip3 install -q -r kairo/requirements.txt 2>/dev/null || true
  log "Backend deps"
  (cd backend && npm install --omit=dev 2>/dev/null) || true
  if [[ -f deploy/env/layered.env.example && ! -f .env ]]; then
    cp deploy/env/layered.env.example .env
    log "Created .env from layered template — fill secrets before production"
  fi
  chmod +x scripts/full-stack-optimize.sh deploy/optimize-all.sh 2>/dev/null || true
  chmod +x akash/bid-optimizer.py kairo/telemetry_daemon.py 2>/dev/null || true
}

print_next_steps() {
  cat <<EOF

=== Bootstrap complete ===
  cd $INSTALL_DIR

  # Dry-run full stack optimize
  DRY_RUN=1 ./scripts/full-stack-optimize.sh

  # Sovereign status
  python3 iteration-100/run.py --status

  # Start backend (separate tmux pane)
  tmux new -s yieldswarm 'cd backend && npm run dev'

  Docs: docs/FULL_STACK_OPTIMIZATION.md docs/PIXEL_TERMUX_SETUP.md

EOF
}

log "YieldSwarm Pixel/Termux bootstrap"
install_packages
if [[ "${SKIP_CLONE:-0}" != "1" ]]; then
  clone_repo
fi
post_clone
print_next_steps

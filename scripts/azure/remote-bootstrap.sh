#!/usr/bin/env bash
# =============================================================================
# remote-bootstrap.sh — run ON a VMSS instance (piped via SSH)
# Installs YieldSwarm mainnet stack without full git clone when --skip-clone.
# =============================================================================
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"
BRANCH="${BRANCH:-main}"
INSTALL_GPU="${INSTALL_GPU:-0}"

log() { printf '[remote-bootstrap] %s\n' "$*"; }

if [[ "$(id -u)" -eq 0 ]]; then
  echo "run as normal user with sudo" >&2
  exit 1
fi

sudo apt-get update -qq
sudo apt-get install -y git curl build-essential python3 python3-pip python3-venv

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

if ! command -v cargo >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
fi

TARGET="${HOME}/yieldswarm-agent-swarm-v2"
if [[ ! -d "${TARGET}/.git" ]]; then
  git clone --branch "${BRANCH}" --depth 1 "${REPO_URL}" "${TARGET}"
fi
cd "${TARGET}"
git fetch origin "${BRANCH}" && git checkout "${BRANCH}" && git pull origin "${BRANCH}" || true

[[ -f .env ]] || cp .env.example .env
python3 -m pip install --user -q -r requirements.txt 2>/dev/null || true
cd backend && npm ci --omit=dev && cd ..
cargo build --release -p yieldswarm-core -p swarm-core 2>/dev/null || true

if [[ "${INSTALL_GPU}" == "1" ]] && command -v nvidia-smi >/dev/null 2>&1; then
  log "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
fi

if command -v systemctl >/dev/null 2>&1; then
  for unit in yieldswarm-backend.service yieldswarm-sovereign.service; do
    sudo sed "s#__REPO__#${TARGET}#g" "${TARGET}/deploy/systemd/${unit}" \
      | sudo tee "/etc/systemd/system/${unit}" >/dev/null
  done
  sudo systemctl daemon-reload
  sudo systemctl enable yieldswarm-backend.service
  sudo systemctl restart yieldswarm-backend.service || true
fi

log "bootstrap complete on $(hostname)"

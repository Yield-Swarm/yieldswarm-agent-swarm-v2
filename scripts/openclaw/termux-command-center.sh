#!/usr/bin/env bash
# Termux command center — SSH, RunPod env, Cherry Servers telemetry, repo sync.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUNPOD_ENV="${HOME}/.env.runpod"
SSH_KEY="${HOME}/.ssh/id_ed25519"
RUNPOD_SSH_USER="${RUNPOD_SSH_USER:-io3xh1krei03ju-644120be}"
RUNPOD_SSH_HOST="${RUNPOD_SSH_HOST:-ssh.runpod.io}"
REPO_URL="${REPO_URL:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"
REPO_DIR="${REPO_DIR:-${HOME}/yieldswarm-agent-swarm-v2}"
CHERRY_BRANCH="${CHERRY_BRANCH:-cursor/cherry-servers-cloud-specs-4f85}"

log()  { printf '[termux-cc] %s\n' "$*" >&2; }
fail() { log "ERROR: $*"; exit 1; }

require_termux() {
  command -v pkg >/dev/null 2>&1 || fail "Run inside Termux (pkg not found)."
}

setup_base() {
  require_termux
  pkg update -y
  pkg install -y openssh git curl tmux rsync python jq
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  if [[ ! -f "${SSH_KEY}" ]]; then
    ssh-keygen -t ed25519 -a 64 -f "${SSH_KEY}" \
      -C "termux-openclaw-$(date -u +%Y%m%dT%H%M%SZ)" -N ""
  fi
  log "Public key — add to RunPod pod → Settings → SSH or web terminal authorized_keys:"
  cat "${SSH_KEY}.pub"
}

sync_repo() {
  if [[ ! -d "${REPO_DIR}/.git" ]]; then
    log "Cloning ${REPO_URL} → ${REPO_DIR}"
    git clone "${REPO_URL}" "${REPO_DIR}"
  fi
  cd "${REPO_DIR}"
  if git diff --quiet package.json 2>/dev/null; then
    :
  else
    log "Stashing local package.json edits before branch switch..."
    git stash push -m "termux-auto-$(date -u +%Y%m%dT%H%M%SZ)" -- package.json 2>/dev/null || git stash
  fi
  git fetch origin "${CHERRY_BRANCH}" main
  git checkout "${CHERRY_BRANCH}" 2>/dev/null || git checkout -b "${CHERRY_BRANCH}" "origin/${CHERRY_BRANCH}"
  git pull --ff-only origin "${CHERRY_BRANCH}" 2>/dev/null || true
  log "Repo ready at ${REPO_DIR} ($(git rev-parse --short HEAD))"
}

load_runpod_env() {
  [[ -f "${RUNPOD_ENV}" ]] || fail "Missing ${RUNPOD_ENV}. Create it with chmod 600 (never commit)."
  # shellcheck disable=SC1090
  set -a && source "${RUNPOD_ENV}" && set +a
  log "Loaded RunPod env from ${RUNPOD_ENV}"
}

show_pubkey() {
  [[ -f "${SSH_KEY}.pub" ]] || fail "No key at ${SSH_KEY}.pub — run: $0 setup"
  cat "${SSH_KEY}.pub"
}

runpod_ssh() {
  [[ -f "${SSH_KEY}" ]] || fail "No SSH key. Run: $0 setup"
  log "Connecting: ${RUNPOD_SSH_USER}@${RUNPOD_SSH_HOST}"
  ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new \
    "${RUNPOD_SSH_USER}@${RUNPOD_SSH_HOST}" "$@"
}

cherry_local() {
  sync_repo
  cd "${REPO_DIR}"
  python3 scripts/telemetry/sys_profile.py
}

cherry_remote() {
  sync_repo
  local remote_cmd
  remote_cmd='cd /workspace 2>/dev/null || cd ~; \
    if [[ -f scripts/telemetry/sys_profile.py ]]; then python3 scripts/telemetry/sys_profile.py; \
    elif command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv; \
    else uname -a && free -h && df -h /; fi'
  runpod_ssh "${remote_cmd}"
}

cherry_collect() {
  sync_repo
  cd "${REPO_DIR}"
  if [[ -n "${RUNPOD_API_KEY:-}" ]]; then
  bash scripts/cherry-servers/collect-all.sh
  else
    log "RUNPOD_API_KEY unset — running local profile only"
    python3 scripts/telemetry/sys_profile.py
    bash scripts/cherry-servers/export-cloud-specs.sh
  fi
}

usage() {
  cat <<EOF
Termux OpenClaw Command Center

Usage: $0 <command> [args...]

Commands:
  setup           Install Termux packages + generate SSH key
  pubkey          Print SSH public key for RunPod
  sync            Clone/pull repo (auto-stash package.json conflicts)
  env             Source ~/.env.runpod (S3 keys — never commit)
  ssh [cmd]       SSH into RunPod pod
  cherry-local    Run sys_profile.py on this phone
  cherry-remote   Run sys_profile on RunPod via SSH
  cherry-collect  Full Cherry Servers packet (local + cloud APIs)
  help            Show this message

Examples:
  $0 setup
  $0 pubkey
  # Add pubkey in RunPod web terminal:
  #   mkdir -p ~/.ssh && echo '<pubkey>' >> ~/.ssh/authorized_keys
  $0 ssh
  $0 cherry-remote
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "${cmd}" in
    setup)         setup_base ;;
    pubkey)        show_pubkey ;;
    sync)          sync_repo ;;
    env)           load_runpod_env ;;
    ssh)           runpod_ssh "$@" ;;
    cherry-local)  cherry_local ;;
    cherry-remote) cherry_remote ;;
    cherry-collect) cherry_collect ;;
    help|-h|--help) usage ;;
    *) fail "Unknown command: ${cmd}. Run: $0 help" ;;
  esac
}

main "$@"

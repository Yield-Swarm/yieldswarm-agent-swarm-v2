#!/usr/bin/env bash
# Install Hugging Face hf CLI + global agent skills (Cursor / Claude Code / fleet).
#
# Usage:
#   export HF_TOKEN=hf_...   # from Vault — never commit
#   ./scripts/fleet/install-hf-agent-skills.sh
#
# Injected by: vmss-worker-bootstrap.sh, swarm_provision.sh, start-termux.sh
set -euo pipefail

log() { printf '[hf-skills] %s\n' "$*" >&2; }

# Agentic mode — hf CLI pivots output for Cursor/Codex when set
export AI_AGENT="${AI_AGENT:-1}"
export CURSOR_AGENT="${CURSOR_AGENT:-1}"

install_cli() {
  if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
    log "WARN: pip not found — install python3-pip first"
    return 1
  fi
  local pipbin=pip3
  command -v pip3 >/dev/null 2>&1 || pipbin=pip
  log "installing huggingface_hub[cli]..."
  "${pipbin}" install -U "huggingface_hub[cli]" >/dev/null 2>&1 || \
    "${pipbin}" install -U "huggingface_hub[cli]"
}

register_skills() {
  if ! command -v hf >/dev/null 2>&1; then
    log "WARN: hf binary not on PATH after install"
    return 1
  fi
  log "registering global agent skills (Cursor / Codex)..."
  if hf skills add --global 2>/dev/null; then
    log "hf skills --global OK"
  else
    log "WARN: hf skills add --global failed (CLI version may not support skills yet)"
  fi
  log "registering Claude Code skills..."
  if hf skills add --claude --global 2>/dev/null; then
    log "hf skills --claude --global OK"
  else
    log "WARN: hf skills add --claude --global failed — upgrade huggingface_hub"
  fi
}

write_profile() {
  local profile_dir="${HF_PROFILE_DIR:-/etc/profile.d}"
  local profile_file="${profile_dir}/yieldswarm_hf.sh"
  local token="${HF_TOKEN:-}"

  if [[ ! -w "${profile_dir}" ]] && [[ "${profile_dir}" == /etc/profile.d ]]; then
    profile_dir="${HOME}/.config/yieldswarm"
    profile_file="${profile_dir}/hf.env"
    mkdir -p "${profile_dir}"
  fi

  {
    echo "# YieldSwarm — Hugging Face agentic CLI (auto-generated)"
    echo "export AI_AGENT=1"
    echo "export CURSOR_AGENT=1"
    [[ -n "${token}" ]] && echo "export HF_TOKEN='${token}'"
    echo "export HF_HUB_ENABLE_HF_TRANSFER=1"
  } >"${profile_file}"
  chmod 644 "${profile_file}" 2>/dev/null || chmod 600 "${profile_file}"
  log "wrote ${profile_file}"

  # User-level skills symlink target (~/.agents/skills)
  mkdir -p "${HOME}/.agents/skills" 2>/dev/null || true
}

verify() {
  if command -v hf >/dev/null 2>&1; then
    hf --version 2>/dev/null || true
    if [[ -n "${HF_TOKEN:-}" ]]; then
      hf auth whoami 2>/dev/null && log "HF auth OK" || log "WARN: hf auth whoami failed — check HF_TOKEN"
    else
      log "HF_TOKEN unset — set from Vault before hub downloads"
    fi
  fi
}

main() {
  install_cli || exit 1
  write_profile
  register_skills || true
  verify
  log "complete — use: hf models ls --format agent"
}

main "$@"

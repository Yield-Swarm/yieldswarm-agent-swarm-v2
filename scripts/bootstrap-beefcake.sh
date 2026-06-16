#!/usr/bin/env bash
# ============================================
# Beefcake 1 Bootstrap Script (Amazon Linux 2023)
# AWS instance i-0b078f1f51b4ec46c — sovereign worker / multicloud burst host
# ============================================
#
# Usage (on instance after SSH):
#   curl -fsSL https://raw.githubusercontent.com/Yield-Swarm/yieldswarm-agent-swarm-v2/main/scripts/bootstrap-beefcake.sh | bash
#   # or upload from laptop:
#   scp -i YSHXYSRL255ascii.pem scripts/bootstrap-beefcake.sh ec2-user@18.218.5.137:~/
#   ssh -i YSHXYSRL255ascii.pem ec2-user@18.218.5.137 'chmod +x ~/bootstrap-beefcake.sh && ~/bootstrap-beefcake.sh'
#
# Optional env:
#   CLONE_REPO=1              git clone yieldswarm repo
#   VAULT_ADDR=...            enable Vault Agent pull after join
#   BEEFCAKE_HOSTNAME=beefcake-1
set -euo pipefail

BEEFCAKE_HOSTNAME="${BEEFCAKE_HOSTNAME:-beefcake-1}"
REPO_URL="${REPO_URL:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/yieldswarm}"

log() { echo "[beefcake-bootstrap] $*"; }

log "Starting Beefcake 1 bootstrap on $(hostname)..."

# Update system
sudo dnf update -y
sudo dnf install -y git curl jq unzip python3 python3-pip

# Docker
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

# AWS CLI v2
if ! command -v aws &>/dev/null; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

# Vault CLI (for AppRole login + kv get)
if ! command -v vault &>/dev/null; then
  VAULT_VERSION="${VAULT_VERSION:-1.17.0}"
  curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
    -o /tmp/vault.zip
  unzip -q /tmp/vault.zip -d /tmp
  sudo mv /tmp/vault /usr/local/bin/vault
  sudo chmod +x /usr/local/bin/vault
  rm -f /tmp/vault.zip
fi

# Layout
mkdir -p "${INSTALL_DIR}"/{keys,scripts,logs,.run}
cd "${INSTALL_DIR}"

if [[ "${CLONE_REPO:-0}" == "1" ]]; then
  if [[ ! -d "${INSTALL_DIR}/yieldswarm-agent-swarm-v2" ]]; then
    log "Cloning ${REPO_URL}"
    git clone "${REPO_URL}" "${INSTALL_DIR}/yieldswarm-agent-swarm-v2"
  fi
  REPO_ROOT="${INSTALL_DIR}/yieldswarm-agent-swarm-v2"
else
  REPO_ROOT="${INSTALL_DIR}"
fi

# Host identity
if command -v hostnamectl &>/dev/null; then
  sudo hostnamectl set-hostname "${BEEFCAKE_HOSTNAME}" 2>/dev/null || true
fi

# Sovereign loop systemd unit (when repo present)
if [[ -f "${REPO_ROOT}/deploy/scripts/start-sovereign-loops.sh" ]]; then
  log "Repo detected — sovereign scripts available at ${REPO_ROOT}"
  cat > "${INSTALL_DIR}/scripts/start-beefcake-loops.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$HOME/yieldswarm/yieldswarm-agent-swarm-v2}"
cd "${REPO_ROOT}"
bash deploy/scripts/start-sovereign-loops.sh start
EOF
  chmod +x "${INSTALL_DIR}/scripts/start-beefcake-loops.sh"
fi

# Vault Agent hook (run after domain join + AppRole issued)
if [[ -n "${VAULT_ADDR:-}" ]]; then
  log "VAULT_ADDR set — writing Vault Agent config stub"
  mkdir -p "${INSTALL_DIR}/vault-agent"
  cat > "${INSTALL_DIR}/vault-agent/agent.hcl" <<EOF
vault {
  address = "${VAULT_ADDR}"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "${INSTALL_DIR}/keys/vault-role-id"
      secret_id_file_path = "${INSTALL_DIR}/keys/vault-secret-id"
    }
  }
}

template {
  source      = "${INSTALL_DIR}/vault-agent/cloud.env.ctmpl"
  destination = "${INSTALL_DIR}/.run/cloud.env"
  perms       = "0600"
}
EOF
  cat > "${INSTALL_DIR}/vault-agent/cloud.env.ctmpl" <<'EOF'
{{- with secret "yieldswarm/data/cloud/aws" -}}
AWS_ACCESS_KEY_ID={{ .Data.data.access_key_id }}
AWS_SECRET_ACCESS_KEY={{ .Data.data.secret_access_key }}
AWS_REGION={{ .Data.data.region }}
{{- end }}
EOF
  log "Place role_id + secret_id in ${INSTALL_DIR}/keys/ then: vault agent -config=${INSTALL_DIR}/vault-agent/agent.hcl"
fi

log "Basic setup complete."
log "Next:"
log "  1. ./scripts/join-yieldswarm-internal.sh   (optional — yieldswarm.internal)"
log "  2. export VAULT_ADDR=... && ./vault/scripts/issue-secret-id.sh beefcake-runtime"
log "  3. CLONE_REPO=1 re-run or git clone manually"
log "  4. make multicloud-preflight && make cloud-scheduler-tick"
log "Beefcake 1 is ready."

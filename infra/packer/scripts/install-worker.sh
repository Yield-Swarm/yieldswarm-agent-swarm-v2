#!/usr/bin/env bash
###############################################################################
# Packer provisioner: bake the AgentSwarm worker runtime into a base image.
#
# Installs Docker (and, when ENABLE_GPU=true, the NVIDIA container toolkit),
# pre-pulls the worker image, and installs the systemd unit. At boot the
# Terraform-rendered cloud-init/startup-script refreshes the env file and
# (re)starts the worker, so image build and runtime config stay decoupled.
###############################################################################
set -euxo pipefail

WORKER_IMAGE="${WORKER_IMAGE:-ghcr.io/yieldswarm/agentswarm-worker:latest}"
ENABLE_GPU="${ENABLE_GPU:-false}"
export DEBIAN_FRONTEND=noninteractive

# Wait for any cloud-init/apt locks held during first boot.
for _ in $(seq 1 30); do
  if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then break; fi
  sleep 5
done

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg jq

# --- Docker -------------------------------------------------------------------
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable docker

# --- Optional NVIDIA stack for GPU workers ------------------------------------
if [ "$ENABLE_GPU" = "true" ]; then
  sudo apt-get install -y ubuntu-drivers-common
  sudo ubuntu-drivers autoinstall || echo "WARN: GPU driver autoinstall failed; ensure the base image ships drivers"
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
fi

# --- Pre-pull the worker image so first boot is fast --------------------------
sudo systemctl start docker
sudo docker pull "$WORKER_IMAGE" || echo "WARN: could not pre-pull $WORKER_IMAGE; it will be pulled at boot"

# --- Seed a placeholder systemd unit (runtime config overrides it at boot) ----
sudo tee /etc/systemd/system/agentswarm-worker.service >/dev/null <<EOF
[Unit]
Description=AgentSwarm fallback worker (placeholder; replaced by cloud-init at boot)
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Restart=always
RestartSec=10
ExecStart=/usr/bin/docker run --rm --name agentswarm-worker --env-file /etc/agentswarm-worker.env $WORKER_IMAGE

[Install]
WantedBy=multi-user.target
EOF

sudo touch /etc/agentswarm-worker.env
sudo systemctl daemon-reload

# --- Clean apt caches to slim the image --------------------------------------
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
echo "AgentSwarm worker runtime baked. Image: $WORKER_IMAGE GPU: $ENABLE_GPU"

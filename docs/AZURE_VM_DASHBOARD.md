# YieldSwarm on Azure VM — Dashboard & Core Setup

Move off Termux to a standard Ubuntu Azure VM for stable paths, proper CPU/RAM, and a browser-accessible dashboard.

## Prerequisites

| Azure resource | Recommendation |
|----------------|----------------|
| VM size | `Standard_D4s_v5` (4 vCPU, 16 GB) or larger |
| OS | Ubuntu 22.04 LTS |
| Disk | 64 GB+ |
| NSG inbound | **TCP 8080** (dashboard API), **TCP 22** (SSH) |

## 1. Connect via SSH

Generate a key (once on your laptop):

```bash
ssh-keygen -t ed25519 -C "yieldswarm-azure" -f ~/.ssh/id_ed25519 -N ""
```

Wire the public key into Azure + Vault:

```bash
export AZURE_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
export AZURE_SUBSCRIPTION_ID="<your-subscription>"
./scripts/azure/wire-ssh-key.sh

# Persist to Vault
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<token>
vault kv patch yieldswarm/providers/azure \
  ssh_public_key="$AZURE_SSH_PUBLIC_KEY" \
  admin_username=azureuser
```

Connect:

```bash
source .run/azure-ssh.env
ssh ${AZURE_ADMIN_USERNAME}@${AZURE_VM_HOST:-YOUR_AZURE_VM_PUBLIC_IP}
```

Or add `config/azure/ssh.config.example` to `~/.ssh/config` as `Host yieldswarm-azure`.

```bash
ssh azureuser@YOUR_AZURE_VM_PUBLIC_IP
```

## 2. One-shot bootstrap (recommended)

On the VM:

```bash
curl -fsSL https://raw.githubusercontent.com/Yield-Swarm/yieldswarm-agent-swarm-v2/main/scripts/azure-vm-bootstrap.sh | bash
```

Or after cloning:

```bash
git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git
cd yieldswarm-agent-swarm-v2
chmod +x scripts/azure-vm-bootstrap.sh
./scripts/azure-vm-bootstrap.sh
```

This installs Git, Node.js 20, Rust, clones/pulls `main`, runs `npm ci` in `backend/`, builds release binaries, and enables the systemd dashboard service.

## 3. Manual setup (step by step)

```bash
sudo apt update && sudo apt install -y git curl build-essential python3 python3-pip

# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Clone
git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git
cd yieldswarm-agent-swarm-v2
cp .env.example .env

# Build
pip3 install --user -r requirements.txt
cd backend && npm ci && cd ..
cargo build --release

# Run dashboard
cd backend && PORT=8080 HOST=0.0.0.0 npm start
```

## 4. Open Azure NSG port 8080

In Azure Portal:

1. VM → **Networking** → **Network security group**
2. **Inbound port rules** → **Add**
3. Destination port: `8080`, Protocol: TCP, Source: your IP (or `Any` for testing)
4. Save

CLI equivalent:

```bash
az network nsg rule create \
  --resource-group yieldswarm-rg \
  --nsg-name YOUR_NSG_NAME \
  --name Allow-YieldSwarm-8080 \
  --priority 1001 \
  --destination-port-ranges 8080 \
  --access Allow \
  --protocol Tcp
```

## 5. Dashboard URLs

Once the backend is running on port **8080**:

| Surface | URL |
|---------|-----|
| **Command Center (TV)** | `http://YOUR_VM_IP:8080/command-center` |
| Arena | `http://YOUR_VM_IP:8080/arena/` |
| Single Pane API | `http://YOUR_VM_IP:8080/api/single-pane/overview` |
| Health | `http://YOUR_VM_IP:8080/api/health` |
| Mining status | `http://YOUR_VM_IP:8080/api/mining/status` |

## 6. systemd (production)

```bash
cd ~/yieldswarm-agent-swarm-v2
sudo cp deploy/systemd/yieldswarm-backend.service /etc/systemd/system/
sudo sed -i "s#__REPO__#$(pwd)#g" /etc/systemd/system/yieldswarm-backend.service
sudo systemctl daemon-reload
sudo systemctl enable --now yieldswarm-backend
sudo systemctl status yieldswarm-backend
```

Optional sovereign loop:

```bash
sudo cp deploy/systemd/yieldswarm-sovereign.service /etc/systemd/system/
sudo sed -i "s#__REPO__#$(pwd)#g" /etc/systemd/system/yieldswarm-sovereign.service
sudo systemctl enable --now yieldswarm-sovereign
```

## 7. Rust particle accelerator (optional)

```bash
cargo run --release -p swarm-core
# or
./target/release/swarm-core
```

## 8. Secrets & Vault

Edit `.env` on the VM with production values:

```bash
nano ~/yieldswarm-agent-swarm-v2/.env
```

Minimum for live mining/auth:

- `VAULT_ADDR`, `VAULT_ROLE_ID`, `VAULT_WRAPPED_SECRET_ID`
- `AGENTSWARM_MASTER_KEY`
- `MINING_ROOT_TAO`, `NEXUS_TREASURY_SOLANA`, etc.

Then:

```bash
./scripts/deploy-mining-production.sh
```

## 9. Alternative: Azure Container Instances

For containerized deploy without managing the VM stack:

```bash
az login
./scripts/deploy-azure-core.sh
```

See `docs/AZURE_ACI_DEPLOY.md`.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Connection refused on :8080 | Check NSG rule; `sudo systemctl status yieldswarm-backend` |
| `npm ci` fails | `cd backend && npm install` |
| Rust build OOM | Use `Standard_D4s_v5` or add swap: `sudo fallocate -l 4G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile` |
| Termux path ghosts | Fresh VM clone — no `~/storage` or proot paths needed |

## Related

- `docs/AZURE_ACI_DEPLOY.md` — container deploy
- `docs/SINGLE_PANE_PROMPTS.md` — full operator map
- `scripts/azure-vm-bootstrap.sh` — automated setup

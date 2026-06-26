# Multi-Platform Deploy Commands

Copy-paste reference for **Helix Chain (long chain)**, **Bash/Linux**, **Windows PowerShell**, **Azure**, and **Akash server**.

Repo root: `$HOME/yieldswarm-agent-swarm-v2` (Linux/Termux) or `C:\Users\YOU\yieldswarm-agent-swarm-v2` (Windows).

---

## 0. Sync repo (all platforms)

### Bash / Linux / Termux / Akash VM / Azure VM

```bash
cd $HOME/yieldswarm-agent-swarm-v2
git remote set-url origin git@github.com:Yield-Swarm/yieldswarm-agent-swarm-v2.git
git fetch origin
git checkout cursor/termux-akash-deploy-597f || git checkout main
git pull --ff-only
npm ci --omit=dev 2>/dev/null || npm install --omit=dev
(cd backend && npm ci 2>/dev/null || npm install)
```

### Windows PowerShell

```powershell
Set-Location $HOME\yieldswarm-agent-swarm-v2
git remote set-url origin git@github.com:Yield-Swarm/yieldswarm-agent-swarm-v2.git
git fetch origin
git checkout cursor/termux-akash-deploy-597f
if ($LASTEXITCODE -ne 0) { git checkout main }
git pull --ff-only
npm ci --omit=dev
if ($LASTEXITCODE -ne 0) { npm install --omit=dev }
Push-Location backend; npm ci; if ($LASTEXITCODE -ne 0) { npm install }; Pop-Location
```

---

## 1. Helix Chain (long chain) activation

### Bash / Linux

```bash
cd $HOME/yieldswarm-agent-swarm-v2
export HELIX_CHAIN_ENABLED=1
export PORT=8080

# Plan only
./scripts/activate-helix.sh --dry-run

# Full genesis + sovereign loops
./scripts/activate-helix.sh

# Verify
curl -s http://127.0.0.1:8080/api/helix/status | jq .
curl -s http://127.0.0.1:8080/api/helix/health | jq .
curl -s http://127.0.0.1:8080/council/status | jq .
```

### Windows PowerShell

```powershell
Set-Location $HOME\yieldswarm-agent-swarm-v2
$env:HELIX_CHAIN_ENABLED = "1"
$env:PORT = "8080"

# Via WSL (recommended — activate-helix.sh is bash)
wsl bash -lc "cd ~/yieldswarm-agent-swarm-v2 && ./scripts/activate-helix.sh"

# Or native: start backend then hit API
npm run prod:backend
Start-Sleep -Seconds 3
Invoke-RestMethod http://127.0.0.1:8080/api/helix/activate -Method POST -ContentType "application/json" -Body '{"source":"powershell"}'
Invoke-RestMethod http://127.0.0.1:8080/api/helix/status
```

### Cross-chain (long-chain execution layer)

```bash
# Preflight GO/NO-GO
./scripts/cross-chain-preflight.sh

# Live strategies (set API keys first)
export CROSS_CHAIN_DRY_RUN=0
make cross-chain-run

# Or via Make
make cross-chain-preflight
make cross-chain-test
```

---

## 2. Termux + own hardware (edge)

See `docs/TERMUX_DEPLOY.md`. Quick:

```bash
cd $HOME/yieldswarm-agent-swarm-v2
cp deploy/env/trident-mainnet.env.example deploy/env/trident-mainnet.env
# nano deploy/env/trident-mainnet.env
chmod +x scripts/termux/*.sh scripts/mining/tandem-pow-launch.sh
export POSEIDON_MODE=edge
npm run termux:deploy
```

---

## 3. Linux (desktop / server / Azure VM / Akash lease shell)

### Full stack (backend + Helix + consensus)

```bash
cd $HOME/yieldswarm-agent-swarm-v2
cp deploy/env/trident-mainnet.env.example deploy/env/trident-mainnet.env
cp deploy/akash.env.example deploy/akash.env
# edit both env files

export POSEIDON_MODE=edge
npm run termux:deploy
./scripts/activate-helix.sh
npm run termux:consensus

curl -s http://127.0.0.1:8080/api/arena/overview | jq .
```

### Backend only (production)

```bash
cd $HOME/yieldswarm-agent-swarm-v2
export PORT=8080
npm run prod:backend
```

### Mining on own hardware

```bash
export MINING_DRY_RUN=0
export WALLET_LTC=LYourLitecoinAddress...
export MINING_PAYOUT_ASSET=LTC
npm run mining:tandem
```

### Next.js dashboard (Linux with full Node)

```bash
export NEXT_DISABLE_SWC=1
npm run termux:dev
```

---

## 4. Windows PowerShell (HP touchscreen / desktop)

### HP dashboard (frontend) or backend worker

```powershell
Set-Location $HOME\yieldswarm-agent-swarm-v2
.\scripts\windows\launch-hp-dashboard.ps1 -Role frontend -Port 3000
# or
.\scripts\windows\launch-hp-dashboard.ps1 -Role backend
```

### Full Poseidon deploy (Windows native)

```powershell
Set-Location $HOME\yieldswarm-agent-swarm-v2
Copy-Item deploy\env\trident-mainnet.env.example deploy\env\trident-mainnet.env -ErrorAction SilentlyContinue
$env:POSEIDON_MODE = "edge"
$env:PORT = "8080"
.\scripts\windows\deploy-poseidon.ps1
```

### Verify (PowerShell)

```powershell
Invoke-RestMethod http://127.0.0.1:8080/api/health
Invoke-RestMethod http://127.0.0.1:8080/api/trident/marketplace-bridge
Invoke-RestMethod http://127.0.0.1:8080/api/helix/status
```

---

## 5. Azure

### A. Login + SSH key wire (Bash on Azure Cloud Shell or Linux)

```bash
cd $HOME/yieldswarm-agent-swarm-v2
az login
export AZURE_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export AZURE_RESOURCE_GROUP=PoseidonMiningGroup
export AZURE_LOCATION=eastus
export AZURE_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"

bash scripts/azure/wire-ssh-key.sh
source .run/azure-ssh.env
```

### B. Azure VMSS mining burst (Bash)

```bash
cd $HOME/yieldswarm-agent-swarm-v2
source .run/azure-ssh.env
source deploy/env/trident-mainnet.env 2>/dev/null || true
export AZURE_VMSS_COUNT=10
bash scripts/azure/deploy-vmss-mining.sh
```

### C. Azure Container Apps / Terraform (Bash)

```bash
cd $HOME/yieldswarm-agent-swarm-v2
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<your-token>
make azure-apply
# or
./scripts/deploy-production.sh azure
```

### D. Azure (Windows PowerShell)

```powershell
Set-Location $HOME\yieldswarm-agent-swarm-v2
Connect-AzAccount
$env:AZURE_SUBSCRIPTION_ID = (Get-AzContext).Subscription.Id
$env:AZURE_RESOURCE_GROUP = "PoseidonMiningGroup"
$env:AZURE_LOCATION = "eastus"
$env:AZURE_SSH_PUBLIC_KEY = Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub -Raw

.\scripts\windows\azure-deploy.ps1 -Action wire-ssh
.\scripts\windows\azure-deploy.ps1 -Action vmss-mining -InstanceCount 10
```

### E. SSH into Azure VM after deploy

```bash
source .run/azure-ssh.env
ssh ${AZURE_ADMIN_USERNAME}@${AZURE_VM_HOST}
# on VM:
cd ~/yieldswarm-agent-swarm-v2 && npm run prod:backend
```

---

## 6. Akash server (GPU lease / provider shell)

Run these **on your laptop, Codespace, or CI** — they talk to Akash mainnet and provision a remote lease.

### A. Install CLI + env (Bash)

```bash
curl -sSfL https://raw.githubusercontent.com/akash-network/provider/main/install.sh | bash
cd $HOME/yieldswarm-agent-swarm-v2
cp deploy/akash.env.example deploy/akash.env
source scripts/akash-env.sh
provider-services keys show yieldswarm -a --keyring-backend os
provider-services query bank balances <akash1...> --node https://rpc.akashnet.net:443
```

### B. Preflight GO/NO-GO

```bash
./scripts/akash-preflight.sh
```

### C. Deploy monolith GPU workers (3× RTX 3090 SDL)

```bash
export AKASH_KEY_NAME=yieldswarm
export AUTO_SELECT_BID=1
export AKASH_PROVIDER=akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<your-token>

make deploy-akash-europlots
# or
./scripts/deploy-to-akash.sh deploy deploy/deploy-swarm-monolith.yaml
```

### D. Deploy integration backend only (light API on Akash)

```bash
export AKASH_KEY_NAME=yieldswarm
./scripts/akash-vault-prepare.sh integration-backend
npm run akash:backend
# or
./scripts/deploy-backend-akash.sh
```

### E. JWT auth (CI / headless Akash server)

```bash
source scripts/akash-env.sh
bash scripts/akash-generate-jwt.sh
source .run/akash-jwt.env
AUTO_SELECT_BID=1 AKASH_AUTH_METHOD=jwt ./scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

### F. Verify lease + wire Arena

```bash
./scripts/verify-akash-lease.sh
source .run/akash-lease.env
curl -s "${AKASH_WORKER_URL}/api/health" | jq .
echo "Arena: /arena?workers=${AKASH_WORKER_URLS}"
```

### G. Akash from Windows PowerShell

```powershell
Set-Location $HOME\yieldswarm-agent-swarm-v2
$env:AKASH_KEY_NAME = "yieldswarm"
$env:AUTO_SELECT_BID = "1"
$env:VAULT_ADDR = "https://vault.yieldswarm.io:8200"
$env:VAULT_TOKEN = "<your-token>"

# WSL path (provider-services is Linux-native)
wsl bash -lc "cd ~/yieldswarm-agent-swarm-v2 && source scripts/akash-env.sh && ./scripts/akash-preflight.sh && make deploy-akash-europlots"

# Or native wrapper if provider-services.exe is on PATH
.\scripts\windows\akash-deploy.ps1 -Target backend
```

### H. Shell into Akash lease (after deploy)

```bash
source .run/akash-lease.env
provider-services lease-status --dseq "$AKASH_DSEQ" --provider "$AKASH_PROVIDER" --node "$AKASH_NODE"
provider-services provider lease-logs --dseq "$AKASH_DSEQ" --provider "$AKASH_PROVIDER" --service backend
# SSH if SDL exposes it — see lease URI in .run/akash-lease.env
```

---

## 7. One-command matrix

| Goal | Bash | PowerShell |
|------|------|------------|
| Helix long chain | `./scripts/activate-helix.sh` | `wsl bash -lc "./scripts/activate-helix.sh"` |
| Termux edge | `npm run termux:deploy` | N/A (use Termux bash) |
| Linux backend | `npm run prod:backend` | `npm run prod:backend` |
| HP dashboard | `npm run termux:dev` | `.\scripts\windows\launch-hp-dashboard.ps1` |
| Azure VMSS mining | `bash scripts/azure/deploy-vmss-mining.sh` | `.\scripts\windows\azure-deploy.ps1 -Action vmss-mining` |
| Azure terraform | `make azure-apply` | `wsl make azure-apply` |
| Akash monolith | `make deploy-akash-europlots` | `.\scripts\windows\akash-deploy.ps1` |
| Akash backend API | `npm run akash:backend` | `wsl npm run akash:backend` |
| Consensus audit | `npm run termux:consensus` | `wsl npm run termux:consensus` |

---

## 8. Health checks (all platforms)

```bash
curl -s http://127.0.0.1:8080/api/health
curl -s http://127.0.0.1:8080/api/trident/marketplace-bridge
curl -s http://127.0.0.1:8080/api/helix/status
curl -s http://127.0.0.1:8080/api/arena/overview
```

```powershell
Invoke-RestMethod http://127.0.0.1:8080/api/health
Invoke-RestMethod http://127.0.0.1:8080/api/trident/marketplace-bridge
Invoke-RestMethod http://127.0.0.1:8080/api/helix/status
```

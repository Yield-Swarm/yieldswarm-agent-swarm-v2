# Azure VMSS deployment — PowerShell (Az module)

Deploy a **16-instance Linux VMSS** with YieldSwarm bootstrap: `GEOCRON_DATA`, `TELEMETRY_STREAM`, `FLEET_API_KEY`, repo clone, and `tmux yieldswarm-backend` on port **8080**.

Aligns with [`docs/HELIX_LIVE_MODE_BLUEPRINT.md`](HELIX_LIVE_MODE_BLUEPRINT.md) and Terraform module [`infra/terraform/modules/azure-vmss/`](../infra/terraform/modules/azure-vmss/).

## Prerequisites

```powershell
Install-Module -Name Az -Repository PSGallery -Force
Connect-AzAccount
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa   # if needed
```

## Quick deploy (Windows PowerShell as Administrator)

```powershell
cd yieldswarm-agent-swarm-v2

Copy-Item scripts/azure/deploy-vmss.config.example.ps1 deploy-vmss.secrets.ps1
notepad deploy-vmss.secrets.ps1   # set FLEET_API_KEY, VmSize, region

. .\deploy-vmss.secrets.ps1
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\azure\deploy-vmss.ps1
```

Dry plan:

```powershell
.\scripts\azure\deploy-vmss.ps1 -WhatIfOnly
```

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| `ResourceGroupName` | `YieldSwarm` | Or `Terminus-Mainnet-RG` |
| `Location` | `centralus` | Match existing LB (`4.249.252.26`) |
| `InstanceCount` | `16` | Fleet compute nodes |
| `VmSize` | `Standard_D4s_v5` | GPU: `Standard_NC24ads_A100_v4` if quota allows |
| `GeoCronData` | `GEOCRON_ALPHA_2026_STREAM` | Injected to `/etc/profile.d/` |
| `TelemetryStream` | backend telemetry URL | Cursor / fleet ingest |
| `FleetApiKey` | from secrets file | **Never commit** — use Vault |

## NSG ports opened

| Port | Purpose |
|------|---------|
| 22 | SSH |
| 8080 | Integration backend |
| 50051 | gRPC telemetry |
| 50000–50003 | Swarm P2P |

Also run existing NSG script for production LB:

```bash
export AZURE_RESOURCE_GROUP=YieldSwarm
export AZURE_NSG_NAME=basicNsgvnet-centralus-nic01
./scripts/azure/configure-swarm-nsg.sh
```

## Bootstrap (per instance)

`scripts/azure/vmss-worker-bootstrap.sh` is injected as VMSS **customData**:

1. Writes `/etc/profile.d/yieldswarm_vmss.sh` with fleet env vars
2. Clones `yieldswarm-agent-swarm-v2` to `/opt/yieldswarm`
3. Starts `tmux` session `yieldswarm-backend` on port 8080
4. Optionally runs `./swarm_provision.sh 8` if `.env.fleet` exists

## Verify

```powershell
az vmss list-instances -g YieldSwarm -n yieldswarm-vmss-cluster -o table
az vmss list-instance-public-ips -g YieldSwarm -n yieldswarm-vmss-cluster -o table
```

```bash
curl http://<instance-ip>:8080/api/helix-nodes/health
curl http://<instance-ip>:8080/api/rewards/status
```

## Terraform alternative

Prefer GitOps / Vault-backed deploy:

```bash
cd infra/terraform
terraform init
terraform apply -var='azure_worker_count=16'
```

## Related

- `swarm_provision.sh` — fleet node roles from `.env.fleet`
- `docs/FLEET_PROVISIONING.md` — Termux / RunPod sync
- `scripts/production/go-live.sh` — disengage dry-run on VMSS

# Azure scripts for YieldSwarm

## Cloud Shell: use PowerShell, not Bash

Azure AKS cmdlets (`New-AzAksNodePool`, etc.) are **PowerShell only**. If you see `bash: New-AzAksNodePool: command not found`, click **Switch to PowerShell** in the Cloud Shell toolbar.

## Spot GPU node pool (PoWUoI / Pearl)

```powershell
az login
cd yieldswarm-agent-swarm-v2
./scripts/azure/aks-spot-mining-pool.ps1 `
  -ResourceGroupName yieldswarm-prod-rg `
  -ClusterName aks-yieldswarm
```

Inventory template: `config/azure/yieldswarm-azure-inventory.example.csv`

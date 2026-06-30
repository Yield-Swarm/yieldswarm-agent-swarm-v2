# Azure AKS spot GPU node pool for PoWUoI / Pearl SRBMiner fleet.
# Run in Azure Cloud Shell — switch to PowerShell (not Bash) before executing.
#
# Usage (PowerShell):
#   az login
#   ./scripts/azure/aks-spot-mining-pool.ps1 -ResourceGroupName yieldswarm-prod-rg -ClusterName aks-yieldswarm

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$ClusterName,

    [string]$NodePoolName = "pouwgpuspot",
    [string]$VmSize = "Standard_NC40ads_H100_v5",
    [int]$Count = 1,
    [string]$MaxPrice = "0.35"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating spot GPU node pool '$NodePoolName' on $ClusterName..." -ForegroundColor Cyan

New-AzAksNodePool `
    -ResourceGroupName $ResourceGroupName `
    -ClusterName $ClusterName `
    -Name $NodePoolName `
    -VmSize $VmSize `
    -Count $Count `
    -Priority Spot `
    -EvictionPolicy Delete `
    -SpotMaxPrice $MaxPrice `
    -EnableAutoScaling `
    -MinCount 0 `
    -MaxCount 4 `
    -Tags @{
        purpose   = "pouw-mining"
        coin      = "PRL"
        swarm     = "mining-pools"
        managedBy = "yieldswarm"
    } `
    -Verbose

Write-Host "Node pool created. Label workloads: nodepool=$NodePoolName" -ForegroundColor Green

# Append to operator inventory CSV if present
$inventory = Join-Path $PSScriptRoot "..\..\config\azure\yieldswarm-azure-inventory.example.csv"
if (Test-Path $inventory) {
    $line = "$NodePoolName,AKS Node Pool (Spot H100),$ResourceGroupName,Central US,your-sub-id,N/A,PoWUoI Pearl SRBMiner spot fleet,variable spot,GPU mining yield"
    Add-Content -Path $inventory -Value $line
    Write-Host "Appended row to $inventory" -ForegroundColor DarkGray
}

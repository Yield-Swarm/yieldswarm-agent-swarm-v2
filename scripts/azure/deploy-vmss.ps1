# =============================================================================
# YieldSwarm / Terminus — Azure VMSS deployment (Az PowerShell module)
# =============================================================================
# Prerequisites:
#   Install-Module -Name Az -Repository PSGallery -Force
#   Connect-AzAccount
#
# Usage:
#   # Copy and edit secrets (never commit deploy-vmss.secrets.ps1)
#   Copy-Item scripts/azure/deploy-vmss.config.example.ps1 deploy-vmss.secrets.ps1
#   . ./deploy-vmss.secrets.ps1
#   ./scripts/azure/deploy-vmss.ps1
#
# Or pass parameters:
#   ./scripts/azure/deploy-vmss.ps1 -InstanceCount 16 -VmSize Standard_D4s_v5
# =============================================================================

[CmdletBinding()]
param(
    [string] $ResourceGroupName = "YieldSwarm",
    [string] $Location = "centralus",
    [string] $VNetName = "yieldswarm-vnet",
    [string] $SubnetName = "mining-subnet",
    [string] $VmssName = "yieldswarm-vmss-cluster",
    [int]    $InstanceCount = 16,
    [string] $VmSize = "Standard_D4s_v5",
    [string] $AdminUsername = "yieldswarm",
    [string] $SshPublicKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub",
    [string] $GeoCronData = "GEOCRON_ALPHA_2026_STREAM",
    [string] $TelemetryStream = "http://127.0.0.1:8080/api/telemetry",
    [string] $FleetApiKey = "",
    [string] $HfToken = "",
    [string] $VaultAddr = "https://vault.yieldswarm.io:8200",
    [switch] $WhatIfOnly
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load optional local secrets file (gitignored)
$SecretsFile = Join-Path (Get-Location) "deploy-vmss.secrets.ps1"
if (Test-Path $SecretsFile) {
    Write-Host "[*] Loading secrets from $SecretsFile" -ForegroundColor DarkGray
    . $SecretsFile
}

if ([string]::IsNullOrWhiteSpace($FleetApiKey)) {
    $FleetApiKey = $env:FLEET_API_KEY
}
if ([string]::IsNullOrWhiteSpace($HfToken)) {
    $HfToken = $env:HF_TOKEN
}
if ([string]::IsNullOrWhiteSpace($FleetApiKey)) {
    Write-Warning "FLEET_API_KEY unset — set in deploy-vmss.secrets.ps1 or env:FLEET_API_KEY"
    $FleetApiKey = "CHANGEME-set-FLEET_API_KEY"
}

if (-not (Get-AzContext)) {
    throw "Not logged in. Run Connect-AzAccount first."
}

if (-not (Test-Path $SshPublicKeyPath)) {
    throw "SSH public key not found: $SshPublicKeyPath — ssh-keygen -t rsa -b 4096"
}
$SshPublicKey = Get-Content $SshPublicKeyPath -Raw

Write-Host "[*] YieldSwarm Azure VMSS deploy" -ForegroundColor Cyan
Write-Host "    RG=$ResourceGroupName Location=$Location Instances=$InstanceCount SKU=$VmSize"

if ($WhatIfOnly) {
    Write-Host "[WhatIf] Would create RG, VNet, NSG, VMSS $VmssName" -ForegroundColor Yellow
    return
}

# --- 1. Resource group -------------------------------------------------------
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Creating resource group..." -ForegroundColor Cyan
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
}

# --- 2. Networking -----------------------------------------------------------
$SubnetConfig = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix "10.0.1.0/24"
if (-not (Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Creating VNet..." -ForegroundColor Cyan
    $VNet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Location $Location `
        -Name $VNetName -AddressPrefix "10.0.0.0/16" -Subnet $SubnetConfig
} else {
    $VNet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName
}

$NsgName = "yieldswarm-vmss-nsg"
$NsgRules = @(
    @{ Name = "Allow-SSH"; Priority = 100; Port = 22 },
    @{ Name = "Allow-Backend-8080"; Priority = 110; Port = 8080 },
    @{ Name = "Allow-gRPC-Telemetry"; Priority = 120; Port = 50051 },
    @{ Name = "Allow-Swarm-P2P"; Priority = 130; Port = "50000-50003" }
)

$RuleConfigs = @()
foreach ($r in $NsgRules) {
    $RuleConfigs += New-AzNetworkSecurityRuleConfig -Name $r.Name -Access Allow -Protocol Tcp `
        -Direction Inbound -Priority $r.Priority -SourceAddressPrefix * -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange $r.Port
}

if (-not (Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NsgName -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Creating NSG..." -ForegroundColor Cyan
    $NSG = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Location `
        -Name $NsgName -SecurityRules $RuleConfigs
} else {
    $NSG = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NsgName
}

$Subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubnetName
if (-not $Subnet) {
    throw "Subnet $SubnetName not found on VNet $VNetName"
}

# --- 3. Bootstrap customData -------------------------------------------------
$BootstrapPath = Join-Path $ScriptDir "vmss-worker-bootstrap.sh"
if (-not (Test-Path $BootstrapPath)) {
    throw "Missing bootstrap script: $BootstrapPath"
}
$BootstrapBody = Get-Content $BootstrapPath -Raw
$Injected = @"
#!/bin/bash
export GEOCRON_DATA='$GeoCronData'
export TELEMETRY_STREAM='$TelemetryStream'
export FLEET_API_KEY='$FleetApiKey'
export HF_TOKEN='$HfToken'
export AI_AGENT='1'
export CURSOR_AGENT='1'
export VAULT_ADDR='$VaultAddr'
$BootstrapBody
"@
$CustomData = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Injected))

# --- 4. VMSS config ----------------------------------------------------------
Write-Host "[*] Building VMSS configuration..." -ForegroundColor Cyan
$VmssConfig = New-AzVmssConfig -Location $Location -SkuCapacity $InstanceCount -SkuName $VmSize `
    -UpgradePolicyMode "Automatic" -Overprovision $false

Set-AzVmssStorageProfile -VmssConfig $VmssConfig `
    -OsDiskCreateOption "FromImage" -OsDiskCaching "ReadWrite" `
    -ImageReferencePublisher "Canonical" `
    -ImageReferenceOffer "0001-com-ubuntu-server-jammy" `
    -ImageReferenceSku "22_04-lts-gen2" `
    -ImageReferenceVersion "latest"

Set-AzVmssOsProfile -VmssConfig $VmssConfig `
    -ComputerNamePrefix "ysnode" `
    -AdminUsername $AdminUsername `
    -CustomData $CustomData `
    -LinuxConfigurationDisablePasswordAuthentication $true

$VmssConfig = Add-AzVmssSshPublicKey -VmssConfig $VmssConfig `
    -KeyData $SshPublicKey -Path "/home/$AdminUsername/.ssh/authorized_keys"

$VmssConfig = Add-AzVmssNetworkInterfaceConfiguration -VmssConfig $VmssConfig `
    -Name "yieldswarm-nic" -Primary $true -SubnetId $Subnet.Id `
    -NetworkSecurityGroupId $NSG.Id -EnableAcceleratedNetworking

# --- 5. Deploy ---------------------------------------------------------------
if (Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName -ErrorAction SilentlyContinue) {
    Write-Host "[*] Updating existing VMSS $VmssName..." -ForegroundColor Cyan
    Update-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName -VirtualMachineScaleSet $VmssConfig | Out-Null
} else {
    Write-Host "[+] Creating VMSS $VmssName ($InstanceCount instances)..." -ForegroundColor Green
    New-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName -VirtualMachineScaleSet $VmssConfig | Out-Null
}

Write-Host "[SUCCESS] VMSS deployed. Next:" -ForegroundColor Green
Write-Host "  1. ./scripts/azure/configure-swarm-nsg.sh   # if using existing LB NSG"
Write-Host "  2. az vmss list-instance-public-ips -g $ResourceGroupName -n $VmssName"
Write-Host "  3. ssh $AdminUsername@<instance-ip> 'tmux attach -t yieldswarm-backend'"

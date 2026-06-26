#Requires -Version 5.1
param(
  [ValidateSet('wire-ssh', 'vmss-mining', 'terraform')]
  [string]$Action = 'wire-ssh',
  [int]$InstanceCount = 10
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root

$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if ($wsl) {
  $wslRoot = wsl wslpath -a $Root
  switch ($Action) {
    'wire-ssh' {
      wsl bash -lc "cd '$wslRoot' && bash scripts/azure/wire-ssh-key.sh"
    }
    'vmss-mining' {
      wsl bash -lc "cd '$wslRoot' && export AZURE_VMSS_COUNT=$InstanceCount && source .run/azure-ssh.env 2>/dev/null; bash scripts/azure/deploy-vmss-mining.sh"
    }
    'terraform' {
      wsl bash -lc "cd '$wslRoot' && make azure-apply"
    }
  }
  exit $LASTEXITCODE
}

# Native Azure CLI fallback
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Install Azure CLI or WSL for azure-deploy.ps1'
}

$rg = if ($env:AZURE_RESOURCE_GROUP) { $env:AZURE_RESOURCE_GROUP } else { 'PoseidonMiningGroup' }
$loc = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { 'eastus' }

switch ($Action) {
  'wire-ssh' {
    if (-not $env:AZURE_SSH_PUBLIC_KEY) {
      $pub = Join-Path $env:USERPROFILE '.ssh\id_ed25519.pub'
      if (-not (Test-Path $pub)) { throw "Set AZURE_SSH_PUBLIC_KEY or create $pub" }
      $env:AZURE_SSH_PUBLIC_KEY = (Get-Content $pub -Raw).Trim()
    }
    az group create --name $rg --location $loc | Out-Null
    az sshkey create --name yieldswarm-deploy-key --resource-group $rg --public-key $env:AZURE_SSH_PUBLIC_KEY | Out-Null
    Write-Host "[azure] SSH key registered in $rg"
  }
  'vmss-mining' {
    throw 'VMSS deploy requires bash template — use WSL: .\scripts\windows\azure-deploy.ps1 -Action vmss-mining'
  }
  'terraform' {
    throw 'Terraform apply — use WSL: wsl make azure-apply'
  }
}

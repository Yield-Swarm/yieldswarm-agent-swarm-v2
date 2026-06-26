#Requires -Version 5.1
param(
  [ValidateSet('preflight', 'monolith', 'backend', 'verify')]
  [string]$Target = 'preflight'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root

$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wsl) {
  throw 'Akash deploy requires WSL/Linux (provider-services). Install WSL and re-run.'
}

$wslRoot = wsl wslpath -a $Root
$cmd = switch ($Target) {
  'preflight' { "cd '$wslRoot' && source scripts/akash-env.sh && ./scripts/akash-preflight.sh" }
  'monolith'  { "cd '$wslRoot' && source scripts/akash-env.sh && make deploy-akash-europlots" }
  'backend'   { "cd '$wslRoot' && source scripts/akash-env.sh && npm run akash:backend" }
  'verify'    { "cd '$wslRoot' && ./scripts/verify-akash-lease.sh" }
}

Write-Host "[akash] $Target via WSL..."
wsl bash -lc $cmd
exit $LASTEXITCODE

#Requires -Version 5.1
# HP Touchscreen — Frontend dashboard (Computer 1) or backend worker (Computer 2)
param(
  [ValidateSet('frontend', 'backend')]
  [string]$Role = 'frontend',
  [int]$Port = 3000
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root

$env:NEXT_DISABLE_SWC = '1'
$env:NEXT_PRIVATE_LOCAL_WEBPACK = 'true'
$env:NODE_OPTIONS = '--max-old-space-size=4096'

if ($Role -eq 'frontend') {
  Write-Host '[hp] Starting Next.js dashboard on port' $Port
  $rule = Get-NetFirewallRule -DisplayName 'Poseidon Dashboard' -ErrorAction SilentlyContinue
  if (-not $rule) {
    New-NetFirewallRule -DisplayName 'Poseidon Dashboard' -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow | Out-Null
  }
  npx next dev --port $Port --no-turbo
} else {
  Write-Host '[hp] Starting integration backend on port 8080'
  Set-Location (Join-Path $Root 'backend')
  $env:PORT = '8080'
  npm start
}

#Requires -Version 5.1
# Poseidon v4.1 — Windows edge deploy (backend :8080, no node_modules hacks)
param(
  [ValidateSet('edge', 'full', 'akash', 'all')]
  [string]$Mode = 'edge'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root

$env:POSEIDON_MODE = $Mode
$env:PORT = if ($env:PORT) { $env:PORT } else { '8080' }
$env:POSEIDON_FOREGROUND = '0'

$envFile = Join-Path $Root 'deploy\env\trident-mainnet.env'
$example = Join-Path $Root 'deploy\env\trident-mainnet.env.example'
if (-not (Test-Path $envFile) -and (Test-Path $example)) {
  Copy-Item $example $envFile
  Write-Host '[poseidon] Created deploy\env\trident-mainnet.env — edit wallets before mining.'
}

New-Item -ItemType Directory -Force -Path (Join-Path $Root 'reports'), (Join-Path $Root '.run') | Out-Null

if (-not (Test-Path (Join-Path $Root 'node_modules'))) {
  npm ci --omit=dev
  if ($LASTEXITCODE -ne 0) { npm install --omit=dev }
}
$backendModules = Join-Path $Root 'backend\node_modules'
if (-not (Test-Path $backendModules)) {
  Push-Location (Join-Path $Root 'backend')
  npm ci
  if ($LASTEXITCODE -ne 0) { npm install }
  Pop-Location
}

# Prefer WSL bash orchestrator when available (parity with Termux/Linux)
$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if ($wsl) {
  $wslRoot = wsl wslpath -a $Root
  wsl bash -lc "cd '$wslRoot' && POSEIDON_MODE=$Mode POSEIDON_FOREGROUND=0 npm run termux:deploy"
  exit $LASTEXITCODE
}

Write-Host '[poseidon] Starting backend on port' $env:PORT
$backendJob = Start-Job -ScriptBlock {
  param($r, $p)
  Set-Location (Join-Path $r 'backend')
  $env:PORT = $p
  npm start
} -ArgumentList $Root, $env:PORT

Start-Sleep -Seconds 4
try {
  Invoke-RestMethod "http://127.0.0.1:$($env:PORT)/api/health" | Out-Null
  Write-Host '[poseidon] Backend healthy'
} catch {
  Write-Warning '[poseidon] Health check pending — see job output'
}

if ($Mode -eq 'full') {
  $env:NEXT_DISABLE_SWC = '1'
  Start-Job -ScriptBlock {
    param($r)
    Set-Location $r
    npx next dev --port 3000 --no-turbo
  } -ArgumentList $Root | Out-Null
  Write-Host '[poseidon] Next.js dev started on :3000'
}

Write-Host '====================================================================='
Write-Host 'STATUS: POSEIDON POD ARMED (Windows)'
Write-Host "Mode:     $Mode"
Write-Host "Backend:  http://127.0.0.1:$($env:PORT)/api/health"
Write-Host 'Bridge:   http://127.0.0.1:' + $env:PORT + '/api/trident/marketplace-bridge'
Write-Host '====================================================================='

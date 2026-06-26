# Helix Duadilateral Chain Routes

Routes all Helix solenoids (**Nexus**, **Helix**, **Shadow**) bidirectionally (duadilateral) to:

| Target | Chain ID | Symbol | Type |
|--------|----------|--------|------|
| **Base** | 8453 | ETH | EVM |
| **Ethereum** | 1 | ETH | EVM |
| **TON** | ton-mainnet | TON | TON API |
| **TAO** | bittensor | TAO | Subtensor |
| **AVAX** | 43114 | AVAX | EVM |

**15 routes** total (3 sources × 5 targets). Config: `config/helix/chain-routes.json`.

## Environment (add to `deploy/env/trident-mainnet.env`)

```bash
export HELIX_CHAIN_ENABLED=1
export NEXUS_CHAIN_URL=http://127.0.0.1:8080/api/helix
export HELIX_CHAIN_URL=http://127.0.0.1:8080/api/helix
export SHADOW_CHAIN_URL=http://127.0.0.1:8080/api/arena/overview

export BASE_RPC_URL=https://mainnet.base.org
export ETHEREUM_RPC_URL=https://eth.llamarpc.com
export TON_RPC_URL=https://tonapi.io
export TON_API_KEY=your_ton_key
export BITTENSOR_RPC_URL=https://entrypoint-finney.opentensor.ai:443
export AVAX_RPC_URL=https://api.avax.network/ext/bc/C/rpc

export TREASURY_BASE_ADDRESS=0x...
export TREASURY_EVM_ADDRESS=0x...
export TREASURY_TON_ADDRESS=...
export TREASURY_TAO_ADDRESS=...
export TREASURY_AVAX_ADDRESS=0x...
```

## Bash / Linux

```bash
cd $HOME/yieldswarm-agent-swarm-v2
source deploy/env/trident-mainnet.env

# Activate Helix + arm all duadilaterals
./scripts/activate-helix.sh

# Or step-by-step
export HELIX_CHAIN_ENABLED=1
npm run prod:backend
curl -s -X POST http://127.0.0.1:8080/api/helix/activate \
  -H 'Content-Type: application/json' \
  -d '{"source":"bash","arm_routes":true}' | jq .

# List all routes (with RPC probes)
curl -s http://127.0.0.1:8080/api/helix/routes | jq .

# Arm routes only
curl -s -X POST http://127.0.0.1:8080/api/helix/routes/arm \
  -H 'Content-Type: application/json' \
  -d '{"source":"bash"}' | jq .

# Sovereign tick receipt
npm run helix:routes:tick
cat .run/helix-duadilateral-last-run.json | jq .
```

## Windows PowerShell

```powershell
$env:HELIX_CHAIN_ENABLED = "1"
$env:BASE_RPC_URL = "https://mainnet.base.org"
$env:ETHEREUM_RPC_URL = "https://eth.llamarpc.com"
$env:TON_RPC_URL = "https://tonapi.io"
$env:BITTENSOR_RPC_URL = "https://entrypoint-finney.opentensor.ai:443"
$env:AVAX_RPC_URL = "https://api.avax.network/ext/bc/C/rpc"

npm run prod:backend
Start-Sleep -Seconds 3

Invoke-RestMethod http://127.0.0.1:8080/api/helix/activate -Method POST `
  -ContentType "application/json" -Body '{"source":"powershell","arm_routes":true}'

Invoke-RestMethod http://127.0.0.1:8080/api/helix/routes
Invoke-RestMethod http://127.0.0.1:8080/api/helix/routes/arm -Method POST `
  -ContentType "application/json" -Body '{"source":"powershell"}'
```

## Termux / Akash / Azure (after backend up)

```bash
curl -s http://127.0.0.1:8080/api/helix/status | jq .duadilateralRoutes
curl -s http://127.0.0.1:8080/api/helix/routes | jq '.routes[] | {id,duadilateral,status,lane}'
```

## Route matrix

| Source → Target | Lane |
|-----------------|------|
| nexus ↔ base | settlement |
| nexus ↔ ethereum | settlement |
| nexus ↔ ton | messaging |
| nexus ↔ tao | inference |
| nexus ↔ avax | settlement |
| helix ↔ base | yield |
| helix ↔ ethereum | yield |
| helix ↔ ton | gaming |
| helix ↔ tao | inference |
| helix ↔ avax | yield |
| shadow ↔ base | arena-nft |
| shadow ↔ ethereum | arena-nft |
| shadow ↔ ton | arena-game |
| shadow ↔ tao | arena-agent |
| shadow ↔ avax | arena-defi |

Status values: `pending` → `armed` → `live` (when RPC probes pass).

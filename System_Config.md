# YIELDSWARM SYSTEM CONFIG — HELIX DNA STRAND v2.1

## CORE IDENTITY
SYSTEM_NAME=YieldSwarm Agent Swarm v2
HELIX_DNA_VERSION=2.1
ASSIMILATION_STATUS=COMPLETE
PRIMARY_NETWORK=production
GOVERNANCE_COUNCIL=14-Council Engine (Nexus)

## KEY ENDPOINTS (live)
BACKEND=http://127.0.0.1:8080
/api/nexus/health
/api/helix/status
/api/shadow/status
/api/iot/health
/api/rewards/status
/api/rewards/sweep
/api/rpc/alchemy/health
/api/single-pane/overview
/api/integrations/marketing/health

## ENVIRONMENT (set before start)
IOT_NETWORK_ID=FWA_37KN9S-IoT
IOT_HUB_DRY_RUN=0
REWARDS_DRY_RUN=0
ALCHEMY_API_KEY=<rotated>
VAULT_ADDR=https://vault.yieldswarm.io:8200
VAULT_TOKEN=<your_token>
BT_NETUID=1
BT_NETWORK=finney
AKASH_OWNER_ADDRESS=akash1YOUR_WALLET
MARKETING_DRY_RUN=1

## TREASURY & MINING ROOTS (config/TREASURY_MANIFEST.json)
NEXUS_TREASURY_SOL=kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN
IOTEX_HUB=0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567
BTC_IOPAY=bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8

REVENUE_SPLIT=Great Delta 50/30/15/5

## HELIX DNA STRANDS
1. IoT Hub          → services/iot_hub/
2. Nexus            → contracts/solenoid/Nexus.sol + services/nexus/
3. Helix            → contracts/solenoid/Helix.sol
4. Shadow           → contracts/solenoid/Shadow.sol
5. Rewards          → services/rewards/ (resharder, assembler, sweeper, orchestrator)
6. RPC Mesh         → backend/src/lib/alchemy.js (164 networks)
7. Marketing        → src/lib/marketing/
8. Mining           → mining/ + scripts/start-mining.sh
9. Tesla/MEGAPOD    → services/rewards/megapod_node.py + docs/TESLA_FLEET_INTEGRATION.md

## QUICK COMMANDS
./scripts/rewards/sweep-rewards.sh --full
./scripts/iot-hub/register-devices.sh
./scripts/start-mining.sh

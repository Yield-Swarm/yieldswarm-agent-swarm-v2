# 4-Swarm Helical Spawn — Dev → Mainnet

Ethical scope: **paid Akash + paid RunPod + owned hardware only** (no free-credit abuse).

## Bootstrap

```bash
cd yieldswarm-agent-swarm-v2
git checkout cursor/swarm-spawn-mainnet-597f
npm run swarm:bootstrap
```

## Swarm tracks

| Swarm | Path | Role |
|-------|------|------|
| 1 Physical | `services/telemetry/physical-core.mjs` | Solar ranch, ASICs, Tesla fleet |
| 2 Multi-mine | `scripts/multi-mine-router.mjs` | PRL/KRX/ZANO paid GPU routing |
| 3 Cosmic | `services/game/cosmic-onboarding.mjs` | 24 houses, 169 clans, RuneScape skills |
| 4 Mesh | `services/mesh/agent-worker-pool.mjs` | 35-layer async agent pool |

## Encrypted IDs (PoW / PoS / PoWUI)

```bash
# Mint via API (:8080 backend)
curl -s -X POST http://127.0.0.1:8080/api/swarm/encrypted-id/mint \
  -H 'Content-Type: application/json' \
  -d '{"type":"pow","rawId":"z15-asic-01"}' | jq .

# Node
node --input-type=module -e "
import { mintPowId, mintPosId, mintPowUiId } from './lib/encrypted-swarm-id.mjs';
console.log(mintPowId('worker'));
console.log(mintPosId('validator'));
console.log(mintPowUiId('dashboard'));
"
```

Set `SWARM_ID_ENCRYPTION_KEY` in production (never commit).

## Multi-mine ($1,400/mo RunPod)

```bash
export RUNPOD_MONTHLY_BUDGET_USD=1400
export MINING_PAID_INSTANCES_ONLY=1
export WALLET_PRL=your_address
MULTI_MINE_DRY_RUN=1 npm run swarm:multi-mine
MULTI_MINE_DRY_RUN=0 npm run swarm:multi-mine:live
```

## Hello-world

```bash
npm run dev          # :3000
npm run swarm:hello  # wallet nonce flow
```

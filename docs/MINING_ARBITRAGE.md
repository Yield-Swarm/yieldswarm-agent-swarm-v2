# Pure Cloud Credit Arbitrage + OpenClaw Mining

> **Mayhem Mode** dual-mining: CPU Monero (XMRig) + GPU Kaspa/Bittensor on pure cloud credits ($0 power).  
> Telemetry feeds **Helix Pillar 5** (Entropy Core) + **Pillar 7** (Ancestral Layer).

## Strategy

| Resource | Miner | Coin | Notes |
|----------|-------|------|-------|
| 64 CPU cores | XMRig | XMR (Monero) | RandomX — ToS-safe on allowed providers |
| 4× GPU | lolMiner / Bittensor | KAS / TAO | Mount binary at `GPU_MINER_BIN` |
| Power cost | $0 | — | Pure credit burn arbitrage |

**Conservative projection:** $3.50–$8.00/day per instance → $35k–$92k/month at 385 instances.

## ToS-safe providers

Set `TOS_ALLOWED_PROVIDERS=vast,runpod,akash,cherry` — mining disabled on unknown providers.

## Files

| Path | Purpose |
|------|---------|
| `deploy/Dockerfile.openclaw` | Dual-mining container image |
| `deploy/openclaw/entrypoint.mining.sh` | Miners + 83°C thermal guard + telemetry |
| `deploy/deploy-openclaw-test.sh` | 5-instance test (~$50 credits) |
| `deploy/full-stack-mining-scale.sh` | Scale 50–400+ instances |
| `deploy/templates/cloud/akash/openclaw.sdl.tmpl.yml` | Akash SDL |
| `deploy/templates/cloud/vast/deploy.sh` | Vast.ai deploy |
| `scripts/profitability-tracker-pure-credit.sh` | Real-time + monthly projections |
| `backend/src/adapters/mining.js` | Helix ingest API |
| `mining/helix-ingest.js` | Entropy-core bridge |

## Quick start

### 1. Configure env

```bash
cp deploy/env/layered.env.example .env
# Set: XMR_POOL_URL, XMR_WALLET, KASPA_POOL_URL, KASPA_WALLET
# Set: VAST_API_KEY (or Akash keys), CLOUD_PROVIDER=vast
```

### 2. Build image (optional)

```bash
docker build -f deploy/Dockerfile.openclaw -t ghcr.io/yield-swarm/openclaw-miner:latest .
```

### 3. Five-instance test

```bash
chmod +x deploy/deploy-openclaw-test.sh deploy/templates/cloud/vast/deploy.sh
OPENCLAW_TEST_COUNT=5 CLOUD_PROVIDER=vast bash deploy/deploy-openclaw-test.sh
```

Dry run:

```bash
DRY_RUN=1 bash deploy/deploy-openclaw-test.sh
```

### 4. Profitability tracker

```bash
bash scripts/profitability-tracker-pure-credit.sh
```

### 5. Scale to 50–400+

```bash
MINING_SCALE_TARGET=50 MINING_SCALE_MAX=400 CLOUD_PROVIDER=vast \
  bash deploy/full-stack-mining-scale.sh
```

### 6. Full-stack mining mode

```bash
bash deploy/deploy-full-stack.sh --mining
MINING_BUILD_IMAGE=1 MINING_TEST_DEPLOY=1 bash deploy/deploy-full-stack.sh --mining
```

## Telemetry / Helix integration

Miners POST to:

```http
POST /api/mining/telemetry
```

Arena overview includes `mining` + `openclawMining` connection.

Local logs:

- `.run/mining/metrics.jsonl` — raw pulses
- `.run/mining-helix.jsonl` — Pillar 5+7 blocks

## Safety

| Guard | Env | Action |
|-------|-----|--------|
| Thermal | `TEMP_CEILING_C=83` | Pause miners, POST `/api/mining/throttle` |
| VRAM | `VRAM_CEILING_GB=29.5` | Log + canopy shield |
| ToS | `TOS_ALLOWED_PROVIDERS` | Disable mining if provider not listed |
| Rollback | `ROLLBACK_ON_FAIL=1` | Stop scale on deploy failure |

## Scaling cheat sheet

```bash
# Test (5 nodes)
OPENCLAW_TEST_COUNT=5 DRY_RUN=1 bash deploy/deploy-openclaw-test.sh

# Production scale (batched)
MINING_SCALE_TARGET=100 MINING_SCALE_BATCH=20 bash deploy/full-stack-mining-scale.sh

# Track credits
CLOUD_CREDIT_BALANCE_USD=3850 OPENCLAW_INSTANCE_COUNT=100 \
  bash scripts/profitability-tracker-pure-credit.sh | jq .projection
```

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/mining/health` | GET | Service health |
| `/api/mining/summary` | GET | Active instances + Helix stats |
| `/api/mining/telemetry` | POST | Ingest mining pulse |
| `/api/mining/throttle` | POST | Thermal throttle ack |

## References

- `docs/MAYHEM_14_PILLAR_ZK.md`
- `scripts/hardware-guard.sh`
- `deploy/entrypoint.monitor.sh`
- `docs/DEPLOYMENT_PRIORITY.md`

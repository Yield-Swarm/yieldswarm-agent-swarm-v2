# Nexus Miner Multi-Mining Deployment — Shadow Solenoid 3

Cross-platform DePIN telemetry bridge: **iOS/Android/Termux/Pebble ingest** → **Singapore Render gateway** → **RunPod compute (Pod 0 & 1)** → **Neon persistent ledger**.

## Topology

```
[ Client Ingestion (iOS / Android / Pebble / Termux) ]
                        │
            Secure webhook telemetry
                        ▼
┌───────────────────────────────────────────────┐
│  Singapore Render — nexus-miner-gateway       │
│  gateway/nexus-miner/server.js                │
│  POST /api/sync  ·  GET /healthz              │
└───────────────────────┬───────────────────────┘
                        │ JSON-RPC / HTTPS
                        ▼
┌───────────────────────────────────────────────┐
│  RunPod Pod 0 & 1 (pytorch CUDA devel)        │
│  scripts/runpod/bootstrap-nexus-miner.sh    │
│  python3 -m mining start --capacity=0.80      │
└───────────────────────┬───────────────────────┘
                        │
                        ▼
         Neon SQL — yieldswarm_miner_profiles
```

Solenoid 3 binds **IoTeX Pebble** (`io_nexus_pebble_01`), **Helium Mobile / Twilio webhooks**, and **Termux controllers** under an **80% execution capacity** barrier to reduce API rate throttling.

## 1. Neon schema

```bash
psql "$DATABASE_URL" -f telemetry/neon/nexus_miner_schema.sql
# or full bundle:
psql "$DATABASE_URL" -f telemetry/neon/schema.sql
```

## 2. Singapore Render gateway

Blueprint entry in `render.yaml` — service `nexus-miner-gateway`, region `singapore`, port `10000`.

**Dashboard secrets** (never commit):

| Variable | Source |
|----------|--------|
| `DATABASE_URL` | Neon connection string |
| `NEXUS_SYNC_API_KEY` | Long random key for `POST /api/sync` |
| `XAI_API_KEY` / `GROK_API_KEY` | Vault `runtime/llm` |
| `TWILIO_*` | Vault `integrations/twilio` |

Local dev:

```bash
cd gateway/nexus-miner
cp ../../deploy/env/nexus-miner.env.example .env   # fill DATABASE_URL
npm ci && npm start
curl http://localhost:10000/healthz
```

After first deploy, set `RENDER_SERVICE_ID` in operator secrets if using `deploy/terraform/scripts/deploy-render.sh`.

## 3. RunPod Pod 0 / Pod 1 activation

On each RunPod worker (`runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04`):

```bash
git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git \
  /opt/openclaw-pod-0/yieldswarm-agent-swarm-v2

mkdir -p ~/.config/yieldswarm
cp deploy/env/nexus-miner.env.example ~/.config/yieldswarm/nexus-miner.env
# Edit with Vault-exported secrets

export RUNPOD_POD_INDEX=0   # or 1 on second pod
chmod +x scripts/runpod/bootstrap-nexus-miner.sh
./scripts/runpod/bootstrap-nexus-miner.sh
```

**Do not** append API keys to `~/.bashrc` in plaintext. Use `~/.config/yieldswarm/nexus-miner.env` or `/etc/profile.d/yieldswarm_nexus_miner.sh` sourced at login.

## 4. Environment reference

Template: `deploy/env/nexus-miner.env.example`

| Variable | Purpose |
|----------|---------|
| `SHADOW_CHAIN_ID` | `shadow-solenoid-3` |
| `EXECUTION_CAPACITY` | `0.80` thread bound |
| `HELIX_CHAIN_RPC` | Helix mainnet bridge |
| `NEXUS_CHAIN_RPC` | IoTeX W3bstream project |
| `IOTEX_DEVICE_ID` | `io_nexus_pebble_01` |
| `NEXUS_GATEWAY_URL` | Singapore sync endpoint |

## 5. Mining CLI

```bash
python3 -m mining start --capacity=0.80
python3 -m mining status --json
```

`EXECUTION_CAPACITY` is persisted in manager status and loaded from env when `--capacity` is omitted.

## 6. Sync API

```bash
curl -X POST "$NEXUS_GATEWAY_URL/api/sync" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $NEXUS_SYNC_API_KEY" \
  -d '{
    "email": "ethyswarm@proton.me",
    "plan": "Lite",
    "currentBalance": 1000,
    "geomines": 0,
    "geodrops": 0,
    "surveys": 0
  }'
```

## Security

- **Never commit** `XAI_API_KEY`, `TWILIO_*`, or `DATABASE_URL`.
- If a key was pasted into chat or shell history, **rotate it immediately** in the xAI console and re-seed Vault.
- Prefer Vault paths: `runtime/llm` (Grok/xAI), `integrations/twilio`, `runtime/nexus`.

## Related

- [`docs/TRI_SOLENOID_ARCHITECTURE.md`](TRI_SOLENOID_ARCHITECTURE.md)
- [`docs/MINING_INFRASTRUCTURE.md`](MINING_INFRASTRUCTURE.md)
- [`docs/FLEET_PROVISIONING.md`](FLEET_PROVISIONING.md)
- [`render.yaml`](../render.yaml)

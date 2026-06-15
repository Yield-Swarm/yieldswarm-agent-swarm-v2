# Bittensor Dual-Purpose Miner — Deploy Guide

RTX 3090 Akash worker running **Ollama + telemetry (8080) + Bittensor axon (8091)**.

## Architecture

| Port | Service |
|------|---------|
| 8080 | Telemetry → Vercel Arena dashboard |
| 8091 | Bittensor axon (validator challenges) |
| 11434 | Ollama inference API |

## Quick start

```bash
# 1. Diagnostic
chmod +x scripts/diagnostic.sh
./scripts/diagnostic.sh
# Paste line under === ACTIVE SYSTEM STATE ===

# 2. Build image
docker build -f deploy/Dockerfile.bittensor-miner -t ghcr.io/yield-swarm/bittensor-miner:latest .
docker push ghcr.io/yield-swarm/bittensor-miner:latest

# 3. Configure
export BT_NETUID=1
export BT_NETWORK=finney
export BT_WALLET_NAME=miner
export BT_HOTKEY_NAME=default
export VAULT_ADDR VAULT_ROLE_ID VAULT_SECRET_ID

# 4. Deploy to Akash
chmod +x deploy/akash/deploy-bittensor.sh
./deploy/akash/deploy-bittensor.sh
```

## Vault secrets (`yieldswarm/bittensor`)

```bash
vault kv put yieldswarm/bittensor \
  wallet_name="miner" \
  hotkey_name="default" \
  wallet_json='{"coldkey":"...","hotkey":"..."}' \
  netuid="1" \
  network="finney" \
  ollama_model="llama3.1:8b"
```

## Arena dashboard

Open `arena/index.html` on Vercel with worker telemetry URLs:

```
https://your-arena.vercel.app/?workers=https://provider-host:8080
```

Polls `/api/telemetry` every 15s for Ollama models, Bittensor status, GPU, inference latency.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `BT_NETUID` | required | Subnet ID |
| `BT_NETWORK` | `finney` | Bittensor network |
| `BT_AXON_PORT` | `8091` | Axon listen port |
| `OLLAMA_MODEL` | `llama3.1:8b` | Pre-loaded model |
| `TELEMETRY_PORT` | `8080` | Arena telemetry |

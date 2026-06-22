# DePIN Edge Integration — 4-task orchestration

Interweaves **local fleet** (Pixel 10a, Pebble, hub `192.168.1.158`) with **IoTeX W3bstream** and **HashiCorp Vault**.

## Tasks

| # | Script | Purpose |
|---|--------|---------|
| 1 | `scripts/edge/edge_gateway_normalizer.sh` | Pebble telemetry → decimal degrees → `.run/iot-edge/` |
| 2 | `scripts/edge/vault_runtime_export.sh` | AppRole/KV → `/tmp/run_secrets/app.env` |
| 3 | `scripts/edge/w3bstream_prover_verify.sh` | SHA-256 attestation hash for W3bstream |
| 4 | `scripts/edge/wan_failover_monitor.sh` | Real ping audit (WAN_TARGETS) |

**Master orchestrator:** `scripts/edge/depin_edge_orchestrate.sh`

## Termux quick start

```bash
cd ~/yieldswarm-agent-swarm-v2
chmod +x scripts/edge/*.sh

export IOT_EDGE_SOURCE=192.168.1.158
export IOT_PEBBLE_DEVICE_ID=io_nexus_pebble_01

# All four tasks
./scripts/edge/depin_edge_orchestrate.sh

# Audit logs
head -n 5 ~/yieldswarm-logs/*.log
```

## Task 2 — Vault (required for production secrets)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=...   # or VAULT_ROLE_ID + VAULT_SECRET_ID — never paste in chat
./scripts/edge/vault_runtime_export.sh
source /tmp/run_secrets/app.env
```

Seed paths (via `vault/scripts/seed-secrets.sh`):

- `integrations/iotex` — `w3bstream_token`, device endpoints
- `providers/aws` — S3 credentials

**Never** hardcode AWS keys in shell scripts. Rotate any credential ever pasted into chat.

## Coordinate engine

Python module: `services/iot_hub/pebble_coords.py`

```
DD = degrees + (decimal_minutes / 60)
```

## Related

- [`docs/IOT_HUB.md`](IOT_HUB.md)
- [`SECRETS.md`](../SECRETS.md)
- `config/iot-hub/network.yaml` — `FWA_37KN9S-IoT`

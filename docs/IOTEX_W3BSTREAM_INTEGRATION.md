# IoTeX W3bstream Integration — Local Hub + Cloud Deploy

> Bridges IoTeX Pebble router telemetry into YieldSwarm via Proof-of-Presence.

---

## Architecture

```
[ IoTeX Pebble / Sensors ] ──RF/BT──> [ Pebble Router ]
                                              │
                                    W3bstream batches
                                              │
                                              v
                    [ POST /api/iotex/ingest ]  (Render / Akash backend)
                                              │
                         +--------------------+--------------------+
                         |                    |                    |
                    [ Neon SQL ]        [ Vault KV ]         [ IoTeX Mainnet ]
```

**Dark fiber / low-latency path:** Singapore Render (`yieldswarm-agent-swarm-v2-mainnet`) ↔ us-west-2 AWS/RunPod via `config/domains.json` weighted routing. Keep primary gateway on `192.168.1.1` — avoid subnet splits from rogue APs.

---

## Environment variables

| Variable | Purpose | Vault path |
|----------|---------|------------|
| `IOTEX_DEVICE_ID` | Pebble device id | `yieldswarm/cloud/iotex` |
| `IOTEX_W3BSTREAM_ENDPOINT` | W3bstream project URL | same |
| `IOTEX_PROJECT_TOKEN` | Bearer auth | same |
| `DATABASE_URL` | Neon persistence (optional) | `yieldswarm/data/neon` |
| `EXECUTION_CAPACITY` | Thread cap (default `0.80`) | — |

Seed Vault:

```bash
make seed-vault   # after setting vars in .env
```

---

## Local hub setup

1. Connect sensors to Pebble router on local RF/BT.
2. Point router at your W3bstream project endpoint.
3. Export env on operator workstation:

```bash
export IOTEX_DEVICE_ID="io_nexus_pebble_01"
export IOTEX_W3BSTREAM_ENDPOINT="https://w3bstream-mainnet.iotex.io/v1/projects/<project>"
export IOTEX_PROJECT_TOKEN="<from-vault>"
```

4. Test ingest:

```bash
curl -X POST http://127.0.0.1:8080/api/iotex/ingest \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"io_nexus_pebble_01","payload":{"lat":39.7,"lon":-104.9,"presence":true}}'
```

---

## Cloud deploy (Render)

Service: `yieldswarm-agent-swarm-v2-mainnet` (Singapore)

1. Set `DATABASE_URL`, IoTeX vars in Render dashboard.
2. Set **Health Check Path** → `/healthz`
3. Run schema: `depin/sql/schema.sql` on Neon.
4. Push `main` → auto-deploy.

```bash
./scripts/smoke-depin.sh https://yieldswarm-agent-swarm-v2-mainnet.onrender.com
```

---

## RunPod workers (OpenClaw)

```bash
# Inside Pod SSH — after fixing publickey auth
export EXECUTION_CAPACITY=0.80
cd /opt/openclaw-pod-0 && pnpm openclaw onboard --install-daemon
python3 -m mining start --capacity=0.80
```

---

## API reference

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/healthz` | Render liveness |
| POST | `/api/sync` | Geominer profile upsert |
| POST | `/api/iotex/ingest` | W3bstream relay |
| GET | `/api/iotex/status` | Config probe |
| GET | `/api/depin/consensus?rounds=100` | HELIX smoke test |

---

## Security

- Never commit `IOTEX_PROJECT_TOKEN`, `AI_GATEWAY_API_KEY`, or xAI keys to git.
- Rotate any key pasted into chat or Amazon Q sessions immediately.
- Rate limits: in-process token bucket; use ElastiCache Redis for multi-instance (see `infra/aws/ton-poe/`).

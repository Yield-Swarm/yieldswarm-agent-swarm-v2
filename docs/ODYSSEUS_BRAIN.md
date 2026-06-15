# Odysseus Central Brain — YieldSwarm on Akash RTX 3090

Odysseus is the **central orchestration brain** for YieldSwarm: persistent memory (ChromaDB), RTX 3090 model routing (LiteLLM + Ollama), and five YieldSwarm-specific tools for Akash leases, treasury, emission router, wallet, and worker telemetry.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │         Akash RTX 3090 Lease            │
                    │                                         │
  Arena / Portal ──►│  yieldswarm-brain :8080                 │
                    │    ├─ ChromaDB memory mesh              │
                    │    ├─ Model router → LiteLLM            │
                    │    └─ YieldSwarm tools (5)              │
                    │                                         │
                    │  odysseus :7000  (workspace UI)         │
                    │  ollama :11434   (local GPU models)    │
                    │  llm-router :4000 (OpenRouter/FW/Ollama)│
                    │  chromadb :8000  (persistent vectors)   │
                    │  odysseus-sync :8097 (peer gossip)      │
                    └─────────────────────────────────────────┘
```

## Components

| Service | Image | Port | Role |
|---------|-------|------|------|
| `yieldswarm-brain` | `ghcr.io/yieldswarm/odysseus-brain` | 8080 | Central brain API |
| `odysseus` | `ghcr.io/yieldswarm/odysseus:main` | 7000 | Workspace / research UI |
| `ollama` | `ollama/ollama` | 11434 | RTX 3090 local inference |
| `llm-router` | `ghcr.io/yieldswarm/litellm-router` | 4000 | Multi-provider routing |
| `chromadb` | `chromadb/chroma` | 8000 | Persistent agent memory |
| `odysseus-sync` | `odysseus-brain` | 8097 | Cross-worker memory sync |

## Quick start (local)

```bash
# Full stack
docker compose -f docker-compose.yml -f docker-compose.odysseus.yml up -d

# Brain only (JSONL memory fallback)
./scripts/start-odysseus-brain.sh

# Memory sync sidecar
./scripts/start-odysseus-brain.sh sync-only
```

## Akash production deploy

```bash
source scripts/lib/vault-env.sh
vault_export_env kv/data/yieldswarm/odysseus/deploy
vault_export_env kv/data/yieldswarm/odysseus/runtime

scripts/deploy-production-odysseus.sh render-akash
AKASH_KEY_NAME=yieldswarm scripts/deploy-production-odysseus.sh akash
```

SDL: `deploy/akash-odysseus.sdl.yml` (RTX 3090, full stack)

## Brain API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Health + secret status |
| GET | `/api/brain/status` | Full brain status |
| GET | `/api/telemetry/odysseus` | Arena-compatible telemetry |
| GET | `/api/models/recommend?task=chat` | Route inference (model + worker + LiteLLM chain) |
| POST | `/api/infer/route` | Route inference (JSON body: task, agent_id, priority) |
| POST | `/api/models/sync` | Force router sync |
| GET | `/api/tools` | List registered tools |
| POST | `/api/tools/execute` | Execute a YieldSwarm tool |
| GET | `/api/memory/recall?q=...` | Query ChromaDB memory |
| POST | `/odysseus/memory/sync` | Trigger peer sync |

### Execute a tool

```bash
curl -s -X POST http://localhost:8080/api/tools/execute \
  -H 'Content-Type: application/json' \
  -d '{"name":"yieldswarm_worker_telemetry","arguments":{"action":"query"}}'
```

## YieldSwarm tools

Registered at brain boot via `register_yieldswarm_tools()`:

1. `yieldswarm_akash_lease` — lease health, top-up, migrate
2. `yieldswarm_treasury_rebalance` — 50/30/15/5 treasury policy
3. `yieldswarm_emission_router_query` — on-chain emission data
4. `yieldswarm_wallet_operation` — unified wallet ops
5. `yieldswarm_worker_telemetry` — Akash + Prometheus metrics

Tool handlers call the integration backend when `YIELDSWARM_*_API_URL` is set (see `backend/src/routes/tools.js`).

## Model routing

`YieldSwarmModelRouter` scores RTX 3090 placements by VRAM, task type, and Great Delta emission weight. The brain syncs decisions every 300s to `.run/odysseus-routing.json` and records them in ChromaDB.

**Live Akash worker sync:** When `AKASH_WORKER_URLS` or `.run/akash-lease.env` is present, workers are probed via `/healthz` and injected into the router automatically (`services/akash_worker_sync.py`). Set `YIELDSWARM_SYNC_AKASH_WORKERS=false` to disable.

```bash
# After Akash lease creation:
source .run/akash-lease.env
curl -X POST http://localhost:8080/api/models/sync

# Export Ollama URL for LiteLLM reload:
source scripts/sync-litellm-from-routing.sh
```

LiteLLM routes:
- **Primary:** `akash-ollama` → Ollama on RTX 3090
- **Fallback:** `yieldswarm-fireworks`, `yieldswarm-default` (OpenRouter)

Config: `config/litellm/config.yaml` (`latency-based-routing`)

## Integration backend

The Express backend proxies Odysseus telemetry for Arena/Portal:

- `GET /api/telemetry/odysseus` → brain `/api/telemetry/odysseus`
- `GET /api/brain/status` → brain status
- `POST /akash/leases`, `/workers/telemetry`, etc. → tool adapter routes

Set `ODYSSEUS_BRAIN_URL=http://<akash-brain-host>:8080` on the backend.

## Environment variables

```bash
ODYSSEUS_API_KEY=
YIELDSWARM_ROUTER_API_KEY=
LITELLM_URL=http://llm-router:4000
ODYSSEUS_WORKSPACE_URL=http://odysseus:7000
ODYSSEUS_CHROMA_HOST=chromadb
ODYSSEUS_CHROMA_PORT=8000
ODYSSEUS_SYNC_PEERS=http://odysseus-sync:8097
ODYSSEUS_ROUTER_SYNC_SECONDS=300
YIELDSWARM_BRAIN_IMAGE=ghcr.io/yieldswarm/odysseus-brain:latest
```

## Tests

```bash
python3 -m unittest tests.test_odysseus_brain -v
```

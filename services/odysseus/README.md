# Odysseus Integration for YieldSwarm

## Overview

Odysseus is the central orchestration and persistent memory layer connecting:

- **10,080 mutated agents** across 120 cron shards (84 agents/shard)
- **169 deity agents** with elevated governance privileges
- **Akash RTX 3090 workers** running Ollama (`llama3.1:70b`)
- **External LLM providers**: Fireworks AI, OpenRouter
- **ChromaDB** shared memory across the swarm
- **Kairo signed telemetry** ingested via Mandelbrot pipeline

## Architecture

```
Kairo Drivers → signed telemetry → Mandelbrot ingest → shard nodes
                                                        ↓
External APIs ← Fireworks/OpenRouter ← Odysseus router → Ollama (3090)
                                            ↓
                                       ChromaDB memory
                                            ↓
                                    10,080 agents / 169 deities
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/odysseus/health` | Service health + agent stats |
| GET | `/api/v1/odysseus/agents/stats` | Full agent/deity/shard stats |
| GET | `/api/v1/odysseus/agents/shard/:id` | Agents in shard |
| GET | `/api/v1/odysseus/providers` | Ollama/Fireworks/OpenRouter config |
| POST | `/api/v1/odysseus/invoke` | Route prompt to agent provider |
| GET | `/api/v1/odysseus/memory/:collection` | Query ChromaDB collection |
| GET | `/api/v1/odysseus/memory/health` | ChromaDB connectivity |

## Provider Routing

Agents are assigned providers round-robin at init:
- Shard N agents 0,3,6... → Ollama (local GPU)
- Shard N agents 1,4,7... → Fireworks
- Shard N agents 2,5,8... → OpenRouter

Override via env:
```bash
OLLAMA_URL=http://ollama-worker:11434
FIREWORKS_API_KEY=...
OPENROUTER_API_KEY=...
CHROMA_URL=http://chromadb:8000
```

## YieldSwarm-Specific Tools

| Tool | Path | Purpose |
|------|------|---------|
| Akash Lease Manager | `tools/akash-lease-manager.py` | Monitor DSEQ, top-up, auto-heal |
| Treasury Operations | `tools/treasury-operations.py` | 20/80 revenue split routing |
| Akash Optimizer | `agents/akash-optimizer.py` | GPU lease optimization |
| Chainlink Vault Manager | `agents/chainlink-vault-manager.py` | Yield capital deployment |

## Deployment

Odysseus deploys as part of the monolith SDL (`deploy/deploy-swarm-monolith.yaml`).

Standalone worker (GPU-only):
```bash
akash tx deployment create deploy/odysseus-worker.yaml --from yieldswarm-deploy
```

## Memory Persistence

All agent interactions are stored in ChromaDB collections named `chroma-shard-{N}`.
Fallback: in-memory store when ChromaDB unavailable (development).

Query example:
```bash
curl https://api.yieldswarm.crypto/api/v1/odysseus/memory/chroma-shard-0?limit=10
```

## Invoke Example

```bash
curl -X POST https://api.yieldswarm.crypto/api/v1/odysseus/invoke \
  -H "Content-Type: application/json" \
  -d '{"agentId":"agent-00042","prompt":"Optimize shard 42 harvesting schedule"}'
```

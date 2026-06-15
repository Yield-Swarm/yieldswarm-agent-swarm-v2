# YieldSwarm AgentSwarm OS v2.0

## Overview
10,080 AI Agents across 120 Cron Jobs
Kimiclaw Consensus Council + SuperGrok Strategy Layer
Helix Chain + Hydrogen Particle Accelerated Shading Tree
$APN on Pump.fun
Unstoppable Domains integration

## Deployment
- Vercel: https://v2-0-bay.vercel.app/
- Project: https://vercel.com/support-6930s-projects/v2-0/c64SWNEkWaF39C4GcjFPYoLxWgMg

## Setup
1. Copy .env.example to .env
2. Fill in values securely
3. Deploy to Vercel or Azure
4. Wire Unstoppable Domains via Cloudflare nameservers

## Odysseus Cookbook Model Routing

YieldSwarm now includes an Akash RTX 3090 model router for Odysseus
Cookbook inference placement.

### Updated routing logic

The router lives in `services/yieldswarm_model_router.py` and is exposed by
`api/yieldswarm_model_routing.py`.

1. Read Akash RTX 3090 worker state from `YIELDSWARM_AKASH_WORKERS`, or create
   `YIELDSWARM_RTX3090_WORKER_COUNT` default workers with 24GB VRAM and a 2GB
   runtime reserve.
2. Read `YIELDSWARM_MODEL_CATALOG`, or use the built-in RTX 3090 catalog:
   Phi 3.5 Mini Q6, Mistral 7B Q5, Llama 3.1 8B Q5, Qwen2.5 Coder 7B Q5,
   DeepSeek R1 Distill 8B Q5, and Mixtral 8x7B Q4.
3. Score every task-compatible model/worker route using:
   - available VRAM after load,
   - model quality and throughput,
   - current worker queue and active request pressure,
   - Great Delta emission score (`GreatDeltaEmissionLogic`),
   - agent mutation fit (`AgentMutationScorer`),
   - a loaded-model bonus and eviction/load penalties.
4. Recommend the highest-scoring route. If the model is already resident, the
   route action is `serve`. If it fits in free VRAM, the action is `load`. If
   idle models must be removed first, the action is `evict_then_load` with
   `unload_before_load` populated.
5. `route_request(..., autoload=True)` dynamically loads the recommended model,
   unloads idle lower-value models when needed, marks the request active, and
   returns the worker/model provider route.
6. `rebalance()` accepts current swarm workload weights and worker pressure,
   preloads models for hot tasks, and unloads idle models from saturated
   workers.

Run the optimizer recommendation snapshot:

```bash
python agents/akash-optimizer.py
```

Run the local routing API:

```bash
python api/yieldswarm_model_routing.py
```

### New API endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Health check for the model routing API. |
| `GET` | `/api/yieldswarm/models` | Return the active model catalog and VRAM budgets. |
| `GET` | `/api/yieldswarm/workers` | Return Akash RTX 3090 worker VRAM, queue, health, and loaded models. |
| `GET` | `/api/yieldswarm/models/recommend?task=chat&agent_id=a1&priority=0.7&mutation_score=0.6` | Recommend the best model route without mutating load state. |
| `GET` | `/api/yieldswarm/models/routes?task=coding` | Return all scored candidate routes for a task. |
| `POST` | `/api/yieldswarm/infer/route` | Select and optionally autoload the best route for an inference request. |
| `POST` | `/api/yieldswarm/infer/complete` | Mark a routed request complete so active counts can drain. |
| `POST` | `/api/yieldswarm/models/load` | Explicitly load a model on a selected or best-fit worker. |
| `POST` | `/api/yieldswarm/models/unload` | Unload an idle model from a selected worker or all workers. |
| `POST` | `/api/yieldswarm/workload/rebalance` | Adjust loaded models based on current swarm task weights and worker pressure. |

Example route request:

```json
{
  "task": "coding",
  "agent_id": "deity-agent-17",
  "priority": 0.8,
  "mutation_score": 0.72,
  "autoload": true
}
```

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
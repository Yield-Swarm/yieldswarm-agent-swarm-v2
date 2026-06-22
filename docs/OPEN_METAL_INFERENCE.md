# Open-Metal Inference — RunPod H100/H200/B200 + Ollama + LiteLLM

Self-hosted open-weight inference cluster with **no third-party API dependency** for agent development.

## Model distribution matrix

| Alias | Open-weight target | Role | RunPod node | Engine |
|-------|-------------------|------|-------------|--------|
| `deepseek-r1-reasoning` | DeepSeek-R1 32B / MoE reasoning | Architecture, proofs, audits | `outdoor_tomato_impala` (B200) | vLLM :8000 |
| `kimi-k2-agent` | Qwen2.5-Coder 32B | Long-horizon swarms, refactors | `single_amber_peafowl` (H200) | vLLM :8001 |
| `qwen-tool-fast` | Qwen2.5 7B | Tool-calling pipeline | `thick_salmon_goat` (H100) | vLLM :8002 |
| `llama-scout-routing` | Llama 3.3 70B | Fast routing / logging | Shared failover | Ollama |
| `phi-eval-fast` | Phi-4 14B | Ultra-fast evaluation | Shared failover | Ollama |

Config: `config/inference/open-metal-matrix.json`

## One-command hotload (master node)

```bash
./scripts/inference/hotload_open_metal_llms.sh
```

### Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Print planned actions |
| `--reset` | Stop existing ollama/vllm/litellm before start |
| `--skip-litellm` | Ollama only |
| `--skip-pull` | Skip `ollama pull` (weights already cached) |

**Important fix vs naive scripts:** models are **`ollama pull`ed**, not `ollama run` in detached screens. Interactive `ollama run` holds VRAM incorrectly for a serving cluster.

## RunPod vLLM shards (each GPU pod)

```bash
# On B200 pod
./scripts/inference/remote-vllm-bootstrap.sh b200

# On H200 pod
./scripts/inference/remote-vllm-bootstrap.sh h200

# On H100 pod
./scripts/inference/remote-vllm-bootstrap.sh h100
```

## Master environment

```bash
# RunPod node hostnames (from enterprise console)
RUNPOD_NODE_B200=outdoor_tomato_impala
RUNPOD_NODE_H200=single_amber_peafowl
RUNPOD_NODE_H100=thick_salmon_goat

# vLLM OpenAI-compatible endpoints
RUNPOD_B200_VLLM_URL=http://outdoor_tomato_impala:8000/v1
RUNPOD_H200_VLLM_URL=http://single_amber_peafowl:8001/v1
RUNPOD_H100_VLLM_URL=http://thick_salmon_goat:8002/v1

# Local backplane
LOCAL_OLLAMA_BASE_URL=http://127.0.0.1:11434
LLM_ROUTER_BIND=127.0.0.1
LLM_ROUTER_PORT=4000
YIELDSWARM_ROUTER_API_KEY=your-long-random-key

# Point Odysseus / agents here
LITELLM_BASE_URL=http://127.0.0.1:4000/v1
ODYSSEUS_DEFAULT_MODEL=qwen-tool-fast
```

## Verification

```bash
./scripts/inference/verify-open-metal.sh

nvidia-smi
curl -s http://127.0.0.1:11434/api/tags | python3 -m json.tool
curl -s http://127.0.0.1:4000/v1/models -H "Authorization: Bearer $YIELDSWARM_ROUTER_API_KEY"
```

## Architecture

```
Agents / Odysseus
       │
       ▼
 LiteLLM :4000  (simple-shuffle router)
   ├── vLLM B200  deepseek-r1-reasoning
   ├── vLLM H200  kimi-k2-agent
   ├── vLLM H100  qwen-tool-fast
   └── Ollama     llama-scout / phi-eval / local fallbacks
```

## Related

- `config/inference/litellm-open-metal.yaml` — router model list
- `docker/entrypoint-ollama.sh` — Akash Ollama worker pattern
- `scripts/sync-litellm-from-routing.sh` — legacy Akash routing sync
- `docs/AKASH_RTX5090_DEPLOY.md` — vLLM container builds

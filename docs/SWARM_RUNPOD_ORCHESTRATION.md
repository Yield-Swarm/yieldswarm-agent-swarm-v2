# 16-Node Termux → RunPod Swarm Orchestration

Staggered launch for **16 Termux instances** over a mobile hotspot, each connecting to RunPod open-metal tiers.

## Per-instance launch (run on each phone)

Assign a **unique** `SWARM_NODE_ID` (1–16) on each Termux terminal:

```bash
# 1. Keep Android awake (hotspot + worker threads)
termux-wake-lock

# 2. Workspace
cd $HOME/yieldswarm-agent-swarm-v2

# 3. Set THIS phone's node id (change per device: 1, 2, 3 … 16)
export SWARM_NODE_ID=1

# 4. Launch Helix orchestrator → RunPod backplane
npm run run-all-onchain
```

### Stagger timing (hotspot NAT protection)

| Node ID | Startup delay |
|---------|---------------|
| 1 | 0s |
| 2 | 3s |
| 3 | 6s |
| … | … |
| 16 | 45s |

Configurable via `config/swarm/16-node-matrix.json` → `stagger_sec`.

## Node → RunPod tier map

| Nodes | Tier | RunPod host | Model alias |
|-------|------|-------------|-------------|
| 1–4 | B200 | `outdoor_tomato_impala` | `deepseek-r1-reasoning` |
| 5–10 | H200 | `single_amber_peafowl` | `kimi-k2-agent` |
| 11–14 | H100 | `thick_salmon_goat` | `qwen-tool-fast` |
| 15–16 | Ollama failover | shared | `llama-scout-routing` / `phi-eval-fast` |

## Environment (optional)

```bash
# Telemetry sink (node 1 starts backend if missing)
SWARM_TELEMETRY_URL=http://<primary-ip>:8080/api/great-delta/telemetry

# RunPod vLLM endpoints (from open-metal hotload)
RUNPOD_B200_VLLM_URL=http://outdoor_tomato_impala:8000/v1
RUNPOD_H200_VLLM_URL=http://single_amber_peafowl:8001/v1
RUNPOD_H100_VLLM_URL=http://thick_salmon_goat:8002/v1
LITELLM_BASE_URL=http://127.0.0.1:4000/v1
```

## Monitor all 16 streams

**Primary node / dashboard:**
```bash
# On node 1 or laptop with repo
./scripts/swarm/status-16-nodes.sh
curl -s http://127.0.0.1:8080/api/telemetry/overview | python3 -m json.tool
```

**Arena / command center:** open `http://<primary>:8080/command-center` — watch telemetry connections increment to 16.

## Hotspot troubleshooting

| Symptom | Fix |
|---------|-----|
| `Network Error` / `Fetch Timeout` on one phone | `CTRL+C`, wait 5s, re-run `npm run run-all-onchain` |
| Node drops after battery < 20% | Keep plugged in; re-run with `termux-wake-lock` |
| NAT bottleneck (many nodes at once) | Ensure unique `SWARM_NODE_ID`; don't skip stagger |

## Dry-run (plan only)

```bash
SWARM_NODE_ID=8 npm run run-all-onchain -- --dry-run
```

## Related

- `docs/OPEN_METAL_INFERENCE.md` — RunPod GPU hotload
- `docs/TERMUX_ENVIRONMENT_SETUP.md` — Termux setup
- `config/swarm/16-node-matrix.json` — full node registry

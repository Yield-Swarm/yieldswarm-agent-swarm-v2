# RunPod inference — realistic open-weight layout (Ollama / vLLM)

Self-hosted inference on your three pods. **Do not** attempt to load fictional model sizes (671B MoE, 1T MoE) via `ollama pull` — those names/sizes in viral spec sheets are not available as single-pod weights.

## Hardware → realistic models

| Pod ID (example) | GPU | VRAM (approx) | Recommended primary model | Role |
|------------------|-----|---------------|---------------------------|------|
| `thick_salmon_goat` | H100 SXM | 80 GB | `qwen2.5-coder:32b` or `deepseek-r1:32b` | Fast tool-calling / code |
| `single_amber_peafowl` | H200 SXM | 141 GB | `llama3.3:70b` or `qwen2.5:72b` | Long-context refactor |
| `outdoor_tomato_impala` | B200 | 192 GB+ | `deepseek-r1:70b` (if fits) or `llama3.3:70b` | Heavy reasoning |

**One primary model per pod** for production. Multi-model on one GPU requires quantization + careful VRAM budgeting — not four concurrent `ollama run` screens.

## Architecture

```
Agent / code-server / Odysseus
        │
        ▼
  OLLAMA_HOST=127.0.0.1:11434  (or vLLM :8000)
        │
   ┌────┴────┬────────────┐
   H100      H200         B200
 (qwen32)  (llama70)   (deepseek70)
```

## Bootstrap (per pod)

```bash
export RUNPOD_POD_ID=thick_salmon_goat   # or peafowl / impala
export INFERENCE_MODEL=qwen2.5-coder:32b
./scripts/runpod/hotload-inference.sh
```

## Verify

```bash
nvidia-smi
curl -s http://127.0.0.1:11434/api/tags | python3 -m json.tool
curl -s http://127.0.0.1:11434/api/generate -d '{"model":"qwen2.5-coder:32b","prompt":"ping","stream":false}'
```

## vLLM (optional, higher throughput)

Use existing repo path for Akash/GHCR vLLM images (`make build-vllm-rtx5090`) adapted per pod with `vllm serve MODEL --tensor-parallel-size 1`.

## Anti-patterns (from your terminal forensics)

| Mistake | Fix |
|---------|-----|
| `pkg` on RunPod Ubuntu | Use `apt-get`, not Termux `pkg` |
| `sudo` as root in container | Drop `sudo` |
| Chained commands without `&&` | One command per line |
| `ollama run` × N in screens on one GPU | One `ollama serve`; API selects model |
| Shark vacuum WiFi AP | Forget rogue AP; use FS-IoT gateway |

## Consensus smoke test (real script)

Use the repo governance runner — not pasted broken TypeScript:

```bash
python3 scripts/run-governance-consensus.py --models 100
```

## 17 domains

Use `scripts/wire-production-domains.sh` with `ROOT_DOMAIN` and Akash lease env — do not commit fabricated `*.amazon.com` placeholder URLs.

## Related

- `docs/COLLABORATIVE_WORKSPACE.md`
- `make akash-preflight` / Track 2 Akash
- `scripts/run-governance-consensus.py`

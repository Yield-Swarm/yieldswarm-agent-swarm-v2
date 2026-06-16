# Akash RTX 5090 Deploy

Production SDLs for **RTX 5090 (32GB)** — **vLLM (recommended)** or Ollama (legacy).

---

## vLLM (recommended)

```bash
make build-vllm-rtx5090
export DEPLOY_IMAGE=ghcr.io/yield-swarm/vllm-rtx5090:latest
make deploy-akash-rtx5090-vllm
curl http://<lease>:8000/v1/models
```

Set `RTX5090_VLLM_BASE_URL=http://<lease>:8000` on the integration backend.

| File | Purpose |
|------|---------|
| `deploy/vllm-rtx5090/Dockerfile` | CUDA 12.4 + vLLM 0.6.0 |
| `deploy/vllm-rtx5090/entrypoint.sh` | AWQ + continuous batching |
| `deploy/akash-rtx5090-vllm.sdl.yml` | Akash SDL (:8000, :9090 metrics) |

---

## Immediate fix: broken apt (Debian buster 404)

If the Akash shell cannot install `curl`, run inside the container:

```bash
bash scripts/akash-buster-apt-recovery.sh
```

Or paste directly:

```bash
echo "deb http://archive.debian.org/debian/ buster main" > /etc/apt/sources.list
echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list
apt-get update -o Acquire::Check-Valid-Until=false
apt-get install -y curl ca-certificates
curl -fsSL https://ollama.com/install.sh | sh
OLLAMA_HOST=0.0.0.0 ollama serve &
ollama pull llama3.1:8b
ollama pull qwen2.5:14b
```

Reply **"Apt fixed"** after this succeeds — the entrypoint handles auto-start on future deploys.

---

## SDL deploy

```bash
export VAULT_TOKEN=...
export DEPLOY_IMAGE=ghcr.io/yield-swarm/ollama-rtx5090:latest
bash scripts/deploy-to-akash.sh deploy deploy/akash-rtx5090-ollama.sdl.yml
```

Files:

| File | Purpose |
|------|---------|
| `deploy/akash-rtx5090-ollama.sdl.yml` | Akash SDL (5090 GPU, Ollama :11434, telemetry :8080) |
| `deploy/akash-rtx5090-entrypoint.sh` | apt recovery + Ollama serve + model pull |
| `scripts/akash-buster-apt-recovery.sh` | One-shot apt fix for live containers |

---

## Dual inference router

Backend routes light tasks to RTX 5090, heavy reasoning to H100:

```bash
# Env (see .env.example)
RTX5090_ENDPOINT=http://your-5090-lease:11434
H100_ENDPOINT=http://your-h100-lease:11434
```

```bash
curl -X POST http://localhost:8080/api/inference/route \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"embed this text","taskType":"embedding"}'
```

Implementation: `backend/src/infrastructure/odysseus-router.js`

| Task type | Backend | Default model |
|-----------|---------|---------------|
| `embedding`, `telemetry`, `masked_prediction`, `simple_classification` | RTX 5090 | `qwen2.5:14b` |
| All other tasks | H100 | `llama3.1:70b` |

---

## Telemetry

Arena / integration backend polls Ollama `/api/ps` every 15s:

```bash
curl http://localhost:8080/api/telemetry/5090
```

Implementation: `backend/src/adapters/rtx5090Telemetry.js`

---

## ROI model

```bash
make akash-roi-5090
```

At $0.72/hr you need ~70–90 tok/s @ $0.25/1M tokens and >75% utilization to break even.

---

## Master prompt + full task list

- [`docs/MASTER_GOD_PROMPT.md`](MASTER_GOD_PROMPT.md)
- [`docs/YIELDSWARM_ALPHA_OMEGA.md`](YIELDSWARM_ALPHA_OMEGA.md)

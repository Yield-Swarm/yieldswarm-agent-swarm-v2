# Akash SDL Budgets & Deployment Guide

> Last updated: June 15, 2026  
> Repo SDL paths under `deploy/`

## Overview

Three prebuilt Akash SDL tiers match the current YieldSwarm architecture. Pick based on budget and what you need live first.

| Tier | SDL file | GPU | Monthly est. | Best for |
|------|----------|-----|--------------|----------|
| **A** | `deploy/akash-backend.sdl.yml` | — | **$45–75** | Arena telemetry API, vault dashboard, integration backend |
| **B** | `deploy/akash-bittensor-miner.sdl.yml` | 1× RTX 3090 | **$230–350** | Kairo DePIN API + Bittensor miner + worker telemetry (dual ROI) |
| **C** | `deploy/akash-odysseus.sdl.yml` | 2× RTX 3090* | **$250–380+** | Full Odysseus stack: workspace, Ollama, brain, ChromaDB, LiteLLM |

\*Tier C requests one GPU profile for `odysseus` and one for `ollama` (can co-locate on strong providers or split).

---

## Tier A — Integration Backend (lightweight)

**File:** `deploy/akash-backend.sdl.yml` (minimal upload ref: `deploy/akash-backend.sdl.minimal.yml`)

| Resource | Spec |
|----------|------|
| CPU | 4 units |
| Memory | 8 GiB |
| Storage | 20 GiB persistent |
| Pricing | 1500 uakt (provider bid) |
| Image | `ghcr.io/yieldswarm/yieldswarm-backend:latest` |
| Port | 8080 global (`/api/health`, `/api/helix/*`, `/api/arena/overview`) |

**Vault paths injected at boot:** `runtime/backend`, `runtime/akash`, `rpc/solana`, `runtime/odysseus`, `treasury/mining_roots`, `iotex`

**Key env (inject at deploy or via Vault):**

- `AKASH_OWNER_ADDRESS` — live worker rows in telemetry
- `VAULT_ADDR` — Vault coordinate (secrets via Agent sidecar in prod)
- `ODYSSEUS_BRAIN_URL` — optional brain upstream
- `KAIRO_API_BASE` — optional Kairo proxy target

---

## Tier B — Bittensor Miner + Telemetry (recommended first GPU)

**File:** `deploy/akash-bittensor-miner.sdl.yml`

| Resource | Spec |
|----------|------|
| CPU | 6 units |
| Memory | 24 GiB |
| Storage | 80 GiB persistent |
| GPU | 1× NVIDIA RTX 3090 (24 GB) |
| Pricing | 7800 uakt |
| Image | `ghcr.io/<owner>/yieldswarm-bittensor-miner:<tag>` |
| Ports | 8091 (Kairo API), 8080 (worker `/healthz`) |

**Key env (Vault-injected in production):**

| Variable | Purpose |
|----------|---------|
| `BT_NETUID` | Bittensor subnet (default `1`) |
| `BT_NETWORK` | `finney` \| `test` |
| `BITTENSOR_MINER_COLDKEY_HEX` | Miner coldkey — **Vault only** |
| `KAIRO_DEPIN_REWARD_RATE` | DePIN reward coefficient |
| `AGENT_SHARD_ID` | Shard for telemetry labels |

Entrypoint: `scripts/bittensor-entrypoint.sh` (Kairo API + worker + optional miner stub).

---

## Tier C — Full Odysseus Inference Stack

**File:** `deploy/akash-odysseus.sdl.yml` (already in repo — production-grade)

Multi-service: Odysseus workspace (:7000), LiteLLM router (:4000), Ollama, central brain (:8080), ChromaDB, SearXNG, sync sidecar.

| Component | CPU | RAM | GPU | Storage (persistent) |
|-----------|-----|-----|-----|-------------------|
| odysseus | 8 | 32Gi | RTX 3090 | 380Gi total |
| ollama | 4 | 16Gi | RTX 3090 | 208Gi |
| yieldswarm-brain | 2 | 4Gi | — | 24Gi |
| chromadb + router + aux | ~5.5 | ~14Gi | — | ~58Gi |

**Monthly estimate:** ~$250–380+ depending on provider bids (sum of per-service uakt pricing in SDL).

Deploy via:

```bash
scripts/deploy-production-odysseus.sh akash
# or
AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/akash-odysseus.sdl.yml
```

---

## Build images

```bash
cp deploy/config.env.example deploy/config.env
# Set GHCR_OWNER, GHCR_TOKEN

# All Akash images (worker, agents, dashboard, backend, bittensor-miner)
make build

# Or individual components:
bash deploy/scripts/build-and-push.sh backend bittensor-miner
```

Image names (default prefix `yieldswarm`):

| Component | GHCR image |
|-----------|------------|
| Backend | `ghcr.io/<owner>/yieldswarm-backend:<tag>` |
| Bittensor miner | `ghcr.io/<owner>/yieldswarm-bittensor-miner:<tag>` |
| Odysseus brain | `ghcr.io/<owner>/odysseus-brain:main` (see `docker/Dockerfile.odysseus-brain`) |

---

## Deploy commands

```bash
export AKASH_KEY_NAME=yieldswarm
export AKASH_OWNER_ADDRESS=akash1...
source scripts/akash-env.sh

# Tier B first (best ROI)
AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/akash-bittensor-miner.sdl.yml

# Tier A — telemetry API
AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/akash-backend.sdl.yml

# Tier C — full Odysseus
AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/akash-odysseus.sdl.yml
```

With Vault-wrapped AppRole (production):

```bash
USE_VAULT_AKASH=1 scripts/akash-deploy-with-vault.sh deploy/akash-bittensor-miner.sdl.yml
```

---

## Query bids (example provider)

```bash
# After deployment create, list bids for your dseq:
provider-services query market bid list \
  --owner "$AKASH_ACCOUNT_ADDRESS" \
  --dseq "$DSEQ" \
  --node "$AKASH_NODE" -o json | jq '.bids[] | {provider: .bid.bid_id.provider, price: .bid.price}'

# Filter providers by attribute (e.g. europlots):
provider-services query market bid list ... -o json \
  | jq '.bids[] | select(.bid.bid_id.provider | contains("europlots"))'
```

Replace `europlots` with your target hostname (e.g. `provider.europlots.com`).

---

## Recommended rollout

1. **Start:** 1× `akash-bittensor-miner.sdl.yml` (Kairo + miner + telemetry on one RTX 3090)
2. **Add:** 1× `akash-backend.sdl.yml` (global Arena API + $5M dashboard proxy)
3. **Scale:** `akash-odysseus.sdl.yml` when you need full Odysseus workspace + Ollama + brain
4. **Optional:** `deploy/deploy-swarm-monolith.yaml` for 3× hardened sovereign workers

---

## Monolith alternative

`deploy/deploy-swarm-monolith.yaml` runs Vault-hardened sovereign workers (3× RTX 3090 profile) — use when you want agents + sovereign loops on Akash instead of splitting tiers.

---

## Security

- Never put `BITTENSOR_MINER_COLDKEY_HEX`, API keys, or wallet seeds in SDL files committed to git.
- Use `vault/setup/05-seed-secrets.sh` + `scripts/akash-deploy-with-vault.sh` for production.
- Set `NETWORK_LOCKDOWN_MODE=true` on production workers.

See `SECRETS.md` and `DEPLOY.md` for Vault paths and Codespaces workflow.

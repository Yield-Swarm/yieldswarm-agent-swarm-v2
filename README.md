# YieldSwarm AgentSwarm OS v2.0

## Overview
10,080 AI Agents across 120 Cron Jobs
Kimiclaw Consensus Council + SuperGrok Strategy Layer
Helix Chain + Hydrogen Particle Accelerated Shading Tree
$APN on Pump.fun
Unstoppable Domains integration

## Core AI Workspace
Odysseus is integrated as the central self-hosted YieldSwarm workspace and
agent-orchestration layer. It is the default interface for the 10,080 mutated
agents and 169 deities, backed by ChromaDB persistent memory and the
OpenAI-compatible LiteLLM router for Fireworks, OpenRouter, and Akash RTX 3090
Ollama workers.

Local stack:
```bash
cp .env.example .env
# Fill router/provider keys and Akash Ollama endpoints.
scripts/deploy-odysseus-stack.sh up
```

Open Odysseus at `http://localhost:7000`, then add the LiteLLM router as an
OpenAI-compatible provider using `http://localhost:4000/v1` and
`YIELDSWARM_ROUTER_API_KEY`.

Akash stack:
```bash
scripts/build-odysseus-images.sh
PUSH=true scripts/build-odysseus-images.sh
scripts/deploy-odysseus-stack.sh render-akash
```

The Akash SDL template is at `deploy/akash-odysseus.sdl.yml`; rendered SDL files
are written under `deploy/rendered/` and ignored by Git.

See `docs/odysseus-yieldswarm.md` for model aliases, memory bootstrap steps,
and Akash Ollama worker requirements.

## Deployment
- Odysseus stack: `docker-compose.yml`
- Akash SDL: `deploy/akash-odysseus.sdl.yml`
- Vercel: https://v2-0-bay.vercel.app/
- Project: https://vercel.com/support-6930s-projects/v2-0/c64SWNEkWaF39C4GcjFPYoLxWgMg

## Setup
1. Copy .env.example to .env
2. Fill in values securely
3. Deploy to Vercel or Azure
4. Wire Unstoppable Domains via Cloudflare nameservers

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
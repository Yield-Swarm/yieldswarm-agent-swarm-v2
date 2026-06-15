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
- Odysseus GPU service:
  - Akash SDL: `deploy/akash/odysseus.sdl.yml`
  - Docker: `Dockerfile`, `docker-compose.yml`, `docker/entrypoint-odysseus.sh`
  - Build workflow: `.github/workflows/build-odysseus.yml`
  - Vault Terraform: `terraform/odysseus/`
  - Production deploy: `scripts/deploy-production-odysseus.sh`

## Setup
1. Copy .env.example to .env
2. Fill in non-secret values securely
3. Store API keys, model hosts, model API keys, and deploy credentials in HashiCorp Vault
4. Deploy to Vercel, Azure, or Akash
5. Wire Unstoppable Domains via Cloudflare nameservers

## HashiCorp Vault
Odysseus deployment artifacts use Vault as the secret source of truth. Keep only
Vault coordinates and workload identity settings in environment variables.

Expected runtime path:
- `kv/data/yieldswarm/odysseus/runtime`
  - `ODYSSEUS_API_KEY`
  - `ODYSSEUS_MODEL_HOST`
  - `ODYSSEUS_MODEL_API_KEY`

Expected deployment path:
- `kv/data/yieldswarm/odysseus/deploy`
  - `image_repository`
  - `AKASH_KEY_NAME`
  - `AKASH_CHAIN_ID`
  - `AKASH_NODE`
  - `AKASH_FEES`

Initialize Vault policy and JWT roles with:
```bash
cd terraform/odysseus
terraform init
terraform apply \
  -var='vault_addr=https://vault.example.com' \
  -var='github_repository=owner/repo'
```

Render or deploy Odysseus with:
```bash
scripts/deploy-production-odysseus.sh render-akash
scripts/deploy-production-odysseus.sh akash
```

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
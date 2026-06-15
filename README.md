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

**Production secrets are managed via HashiCorp Vault.** See [SECRETS.md](SECRETS.md) for the complete setup guide.

1. Bootstrap Vault: `./vault/scripts/bootstrap.sh`
2. Seed secrets: `./vault/scripts/seed-secrets.sh`
3. Apply infrastructure: `cd terraform && terraform apply`
4. Build image: `docker build -f docker/Dockerfile -t ghcr.io/yieldswarm/agentswarm:latest .`
5. Deploy to Akash: `./akash/deploy.sh`

For local development only, copy `.env.example` to `.env` and use a dev Vault instance.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
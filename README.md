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
1. Review `.env.example` for local non-production placeholders only.
2. Configure HashiCorp Vault secrets, policies, and AppRole with `SECRETS.md`.
3. Run Terraform from `infra/terraform` so Azure, RunPod, Vultr, DigitalOcean, and RPC credentials are pulled from Vault.
4. Build and deploy the Akash image with `deploy/akash/entrypoint.sh` so secrets are injected at container startup.
5. Wire Unstoppable Domains via Cloudflare nameservers.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Secrets
Production secrets must be stored in HashiCorp Vault, never in Git, rendered deployment manifests, or Terraform variable files. See [SECRETS.md](SECRETS.md) for the exact setup and deployment commands.
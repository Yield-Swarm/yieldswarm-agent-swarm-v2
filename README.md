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
1. **Production secrets:** Follow [SECRETS.md](SECRETS.md) to bootstrap HashiCorp Vault
2. **Terraform:** `cd terraform && terraform init && terraform plan -var-file=environments/prod.tfvars`
3. **Akash:** Build with `docker build -f akash/Dockerfile .` and deploy via `akash/scripts/deploy.sh`
4. **Local dev:** Copy `.env.example` to `.env` for reference only (Vault preferred)
5. Wire Unstoppable Domains via Cloudflare nameservers

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
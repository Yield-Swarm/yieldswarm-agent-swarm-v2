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
1. Bootstrap HashiCorp Vault — see [SECRETS.md](SECRETS.md) for exact commands
2. Store secrets in Vault KV (`yieldswarm/` mount) — never commit `.env`
3. Run Terraform to provision cloud resources (secrets pulled from Vault)
4. Build and deploy Akash container (runtime secret injection via Vault Agent)
5. Wire Unstoppable Domains via Cloudflare nameservers

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
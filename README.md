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
1. Bootstrap HashiCorp Vault — see [SECRETS.md](SECRETS.md)
2. Write cloud secrets to Vault (`azure`, `runpod`, `vultr`, `digitalocean`, `rpc`, `akash`)
3. Run Terraform (`terraform/`) — credentials pulled from Vault at apply time
4. Build and deploy Akash image — see [DEPLOY.md](DEPLOY.md)
5. Wire Unstoppable Domains via Cloudflare nameservers

## Secrets
All production credentials live in Vault KV (`yieldswarm/` mount). See [SECRETS.md](SECRETS.md) for exact commands.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
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
1. Bootstrap Vault, policies, and AppRoles from `infra/vault/bootstrap`
2. Write provider and runtime secrets into Vault KV v2
3. Run Terraform from `infra/terraform` so provider credentials are read from Vault
4. Render `deploy/akash/openclaw.local.sdl` from `deploy/akash/openclaw.sdl.tpl`
5. Deploy OpenClaw with runtime Vault injection

See `SECRETS.md` for the exact production setup commands.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Complete the Vault-backed bootstrap in `SECRETS.md` before any production deployment.
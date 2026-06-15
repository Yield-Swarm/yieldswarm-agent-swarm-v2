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
1. Copy .env.example to .env
2. Fill in values securely
3. Deploy to Vercel or Azure
4. Wire Unstoppable Domains via Cloudflare nameservers

## Secrets management
Production secrets are managed via HashiCorp Vault — see
[`SECRETS.md`](SECRETS.md) for the operator runbook and
`infrastructure/{vault,terraform,akash}/` for the implementation.
`.env` files are only used for local development; **never** for
production workloads.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
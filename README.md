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

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Mega Task Deliverables

| Doc | Description |
|-----|-------------|
| [MERGE_STRATEGY.md](./MERGE_STRATEGY.md) | Branch structure + merge commands |
| [DEPLOY.md](./DEPLOY.md) | Akash + Vault production deployment |
| [DOMAINS.md](./DOMAINS.md) | Unstoppable Domains + Cloudflare DNS |

## Services

```bash
cd services/api && npm install && npm run dev   # API on :3000
./scripts/akash-deploy.sh --env production --dry-run
```

## Dashboards

- [Kairo Driver Contribution](./dashboard/kairo-contribution.html)
- [$5M Telemetry](./dashboard/telemetry-5m.html)
- [Council Status](./council/status.html)

## Branch Structure

`main` → `development` → `testnet` → `devnets` → `production` → `MAINNET`

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys. See DEPLOY.md for Akash.
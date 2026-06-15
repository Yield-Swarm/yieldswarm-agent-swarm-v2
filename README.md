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
1. Bootstrap Vault engines, policies, and AppRoles with `infra/vault`
2. Populate cloud, RPC, and Akash runtime secrets using `SECRETS.md`
3. Run Terraform from `infra/terraform` with a Vault-issued token
4. Build and deploy the Akash image with runtime Vault injection
5. Wire Unstoppable Domains via Cloudflare nameservers

## Business
Wise: cbrown03777@gmail.com
Keep API keys in Vault only; `.env.example` contains placeholders.

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.
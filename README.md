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
1. Bootstrap HashiCorp Vault engines, policies, and AppRoles with Terraform.
2. Seed Azure, RunPod, Vultr, DigitalOcean, RPC, Akash, signing, and LLM secrets into Vault KV v2.
3. Run Terraform stacks with Vault-backed data sources instead of local tfvars secrets.
4. Build the Akash agent image and deploy with a one-use wrapped Vault AppRole SecretID.
5. Wire Unstoppable Domains via Cloudflare nameservers.

See [SECRETS.md](SECRETS.md) for exact commands.

## Business
Payment, Unstoppable Domains, and business contact credentials must be stored in Vault only.

## Next
Use the Vault-backed deployment flow in [SECRETS.md](SECRETS.md). Never commit or paste production secrets into GitHub, Akash SDL files, Terraform tfvars, or deployment dashboards.
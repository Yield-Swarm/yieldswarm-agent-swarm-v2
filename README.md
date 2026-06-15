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
1. Bootstrap HashiCorp Vault and load secrets with `SECRETS.md`
2. Run Terraform from `infra/terraform` so Azure, RunPod, Vultr, DigitalOcean, and RPC credentials are read from Vault
3. Build the Akash image from `docker/akash/Dockerfile`
4. Render `deploy/akash/deploy.tpl.yml` with a one-use wrapped Vault SecretID and deploy to Akash
5. Wire Unstoppable Domains via Cloudflare nameservers

## Business
Wise: cbrown03777@gmail.com
UD API keys and all runtime secrets are stored in Vault.

## Next
Follow `SECRETS.md` to rotate secrets and deploy without committing credentials.
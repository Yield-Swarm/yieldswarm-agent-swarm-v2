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
- Vault-backed Terraform and Akash deployment assets now live in:
  - `infra/vault/`
  - `docker/Dockerfile.akash`
  - `deploy/akash/deployment.sdl.tpl.yml`

## Setup
1. Provision Vault mounts, policies, and AppRoles from `infra/vault/`
2. Write Azure, RunPod, Vultr, DigitalOcean, RPC, and runtime app secrets into Vault
3. Build and publish the Akash image from `docker/Dockerfile.akash`
4. Render the Akash SDL from `deploy/akash/deployment.sdl.tpl.yml`
5. Inject the non-committed Vault bootstrap env file into the running lease

Use `SECRETS.md` for the exact production commands. The old local `.env` workflow is no longer the source of truth for secrets.

## Business
Wise: cbrown03777@gmail.com
Secrets are no longer stored in tracked files.

## Next
Follow `SECRETS.md`, keep bootstrap files under `.secrets/`, and rotate AppRole secret IDs for every deployment or operator handoff.
# YieldSwarm AgentSwarm OS v2.0

## Overview
10,080 AI Agents across 120 Cron Jobs
Kimiclaw Consensus Council + SuperGrok Strategy Layer
Helix Chain + Hydrogen Particle Accelerated Shading Tree
$APN on Pump.fun
Unstoppable Domains integration

## Deployment
- Application deployment targets include Vercel, Azure, and Akash.
- Production secrets are managed through HashiCorp Vault and documented in `SECRETS.md`.

## Setup
1. Read `SECRETS.md` and bootstrap Vault before any production deployment.
2. Copy `.env.example` to `.env` only for local smoke tests.
3. Inject runtime secrets from Vault for Akash and other hosted environments.
4. Deploy the application stack after Vault policies, AppRole, and secret paths are in place.

## Next
Complete provider-specific infrastructure on top of the Vault-backed secret contract in `infra/terraform/vault`.
# YieldSwarm AgentSwarm OS v2.0

## Overview
10,080 AI Agents across 120 Cron Jobs
Kimiclaw Consensus Council + SuperGrok Strategy Layer
Helix Chain + Hydrogen Particle Accelerated Shading Tree
$APN on Pump.fun
Unstoppable Domains integration

## Deployment
- **Vercel:** https://v2-0-bay.vercel.app/
- **Project:** https://vercel.com/support-6930s-projects/v2-0/c64SWNEkWaF39C4GcjFPYoLxWgMg
- **Akash:** `make deploy` or `./scripts/akash-deploy.sh`
- **Multi-cloud fallback:** `infra/terraform/` (Helixchainprod workspace)
- **Secrets:** HashiCorp Vault — see `SECRETS.md`

## Quick start

```bash
cp .env.example .env
cp deploy/config.env.example deploy/config.env
make preflight          # verify tooling
make deploy             # full production deploy
```

## Documentation

| Doc | Purpose |
|-----|---------|
| `DOMAINS.md` | Unstoppable Domains wiring (17 domains, exact records) |
| `DEPLOY.md` | Production deployment orchestrator (5 steps) |
| `SECRETS.md` | HashiCorp Vault bootstrap + Akash runtime secrets |
| `BRANCHES.md` | Branch ladder: development → MAINNET |
| `HELIX-EXECUTION.md` | Parallel track execution plan |
| `infra/README.md` | Multi-cloud Terraform + Packer |

## Setup
1. Copy `.env.example` to `.env` and fill values via Vault
2. Bootstrap Vault: `./vault/scripts/bootstrap.sh`
3. Wire domains per `DOMAINS.md`
4. Deploy: `make deploy`
5. Promote branches per `BRANCHES.md`

## Business
Wise: cbrown03777@gmail.com
UD API Key: store in Vault, not in repo

## Structure

```
deploy/          # Production orchestrator (Docker, Akash SDL, monitoring)
akash/           # Lease manager, worker SDL, Vault runtime
infra/           # Multi-cloud Terraform + Packer (Azure, GCP, RunPod, Vultr)
terraform/       # Vault-backed provider modules
vault/           # Policies, bootstrap, seed scripts
scripts/         # akash-deploy.sh
kairo/           # (coming) Cryptographic identity app
```

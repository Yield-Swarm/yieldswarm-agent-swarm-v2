# Production Spin-Up Guide

Multi-platform deployment for **Vercel + Render + Akash + Azure + HashiCorp Vault**.

## Recommended priority order

1. **HashiCorp Vault** — foundational; all other platforms pull secrets from here
2. **Akash** — GPU workers + Bittensor revenue
3. **Vercel** — user-facing frontend + payments (fastest path to revenue)
4. **Render** — integration API fallback / always-on backend
5. **Azure** — Container Apps fallback when Akash bids are thin

## Quick start (15-minute path)

```bash
# 1. Config
cp deploy/config.env.example deploy/config.env
cp .env.example .env   # fill placeholders — never commit

# 2. Vault (operator workstation)
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<admin-token>
make vault-bootstrap      # policies + AppRoles
make seed-vault           # KV from .env

# 3. Preflight
make preflight
make vault-check

# 4. Build images
make build                # worker, agents, dashboard, backend → GHCR

# 5. Deploy Akash (Vault-injected)
make akash-deploy-vault   # default monolith SDL

# 6. Wire frontend + loops
make frontend
make monitoring-up
make sovereign-up
```

## Platform matrix

| Platform | Entry command | Secrets source | Key artifacts |
|----------|---------------|----------------|---------------|
| **Vault** | `make vault-bootstrap` | Operator token | `vault/`, `terraform/vault.tf` |
| **Akash agent** | `make akash-deploy-vault` | Wrapped SecretID → Vault Agent | `deploy/deploy-swarm-monolith.yaml` |
| **Akash Bittensor** | `make akash-bittensor` | `bittensor-runtime` AppRole | `deploy/akash-bittensor-miner.sdl.yml` |
| **Akash Odysseus** | `make akash-odysseus` | `akash-runtime` AppRole | `deploy/akash/odysseus-vault.sdl.yml` |
| **Akash backend** | `make akash-backend` | `akash-runtime` AppRole | `deploy/akash-backend.sdl.yml` |
| **Vercel** | `make vercel` / `vercel deploy --prod` | Vercel env dashboard | `vercel.json` |
| **Render** | `make render` | Render secret store | `render.yaml` |
| **Azure** | `make azure-apply` | Vault `providers/azure` | `terraform/azure.tf` |
| **Fallback** | `make terraform-apply` | `deploy/config.env` | `deploy/terraform/` |

## Unified deploy script

```bash
./scripts/deploy-production.sh <target>

# Targets: all | vault | akash | akash-bittensor | akash-odysseus |
#          akash-backend | terraform | azure | vercel | render |
#          frontend | status
```

Equivalent to `make production` for full pipeline.

## Akash SDL catalog

| SDL | Workload | Vault |
|-----|----------|-------|
| `deploy/deploy-swarm-monolith.yaml` | Agent shard (RTX 3090) | AppRole wrap + Vault Agent |
| `deploy/akash-bittensor-miner.sdl.yml` | Bittensor + telemetry | `bittensor-runtime` wrap |
| `deploy/akash/odysseus-vault.sdl.yml` | Odysseus GPU | AppRole wrap + Vault Agent |
| `deploy/akash-backend.sdl.yml` | Integration API | AppRole wrap + hvac |
| `akash/deploy.yaml` | Minimal agent shard | AppRole wrap |

**No application secrets in any SDL.** Only bootstrap coordinates (`VAULT_ROLE_ID`, `VAULT_WRAPPED_SECRET_ID`, `AGENT_SHARD_ID`).

## HashiCorp setup

### Vault server

Vault is **not** provisioned by application code — bootstrap on your HCP/self-hosted instance:

```bash
./vault/setup/bootstrap.sh          # imperative
# OR
cd vault/terraform-vault-config && terraform apply   # declarative
```

### AppRoles

| Role | Use |
|------|-----|
| `ci-bootstrap` | CI mints wrapped SecretIDs |
| `akash-runtime` | Agent / Odysseus / backend on Akash |
| `bittensor-runtime` | Bittensor miner |
| `terraform` | `terraform/` cloud apply |

### Mint wrap manually

```bash
eval "$(./vault/scripts/issue-secret-id.sh akash-runtime 10m)"
```

See [docs/VAULT_AKASH_RUNTIME.md](docs/VAULT_AKASH_RUNTIME.md).

## Terraform layout

| Path | Purpose |
|------|---------|
| `terraform/` | **Primary** — Vault-fed Azure Container Apps + RunPod/Vultr/DO |
| `deploy/terraform/` | Health-probe fallback → Fly / Render / Hetzner |
| `infra/terraform/` | Alternate VMSS-based Azure/GCP (legacy) |

**Single recommended path for Azure:** `make azure-apply` → `terraform/` with `envs/prod/backend.hcl`.

## Vercel

```bash
vercel deploy --prod
```

Routes defined in `vercel.json`: Kairo, dashboard, council, Next.js app, payments.

Set in Vercel dashboard: `KAIRO_API_BASE`, `MAPBOX_TOKEN`, Stripe keys (see `docs/ENV_VARS.md`).

## Render

1. Connect repo → Blueprint → `render.yaml`
2. Set `SOLANA_RPC_URL`, `TREASURY_ADDRESS`, `VAULT_TOKEN` in Render secrets
3. Health check: `/api/health`

## Environment variables

- **Catalog:** `docs/ENV_VARS.md` (~180 names, placeholders only)
- **Deploy infra:** `deploy/config.env.example`
- **App secrets:** `.env.example` → Vault via `vault/scripts/seed-secrets.sh`

**Never commit:** `VAULT_TOKEN`, `VAULT_WRAPPED_SECRET_ID`, API keys, mnemonics.

## Production readiness checklist

- [ ] Vault bootstrapped + seeded
- [ ] `deploy/config.env` filled (GHCR, Akash wallet)
- [ ] Images pushed to GHCR (`make build`)
- [ ] Akash lease live with Vault injection (`make akash-deploy-vault`)
- [ ] Auto-heal running (`make akash-heal`)
- [ ] Frontend wired (`make frontend`)
- [ ] Vercel deployed
- [ ] Render blueprint applied (optional)
- [ ] Sovereign loops running (`make sovereign-up`)
- [ ] Monitoring up (`make monitoring-up`)

## Related docs

- [PRODUCTION_READINESS.md](PRODUCTION_READINESS.md)
- [docs/AKASH_DEPLOY.md](docs/AKASH_DEPLOY.md)
- [docs/VAULT_AKASH_RUNTIME.md](docs/VAULT_AKASH_RUNTIME.md)
- [SECRETS.md](SECRETS.md)
- [DEPLOY.md](DEPLOY.md) (if present)

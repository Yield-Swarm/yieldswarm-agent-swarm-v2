# Deployment Guide

Unified deployment across **Vercel, Render, Akash, Azure, and HashiCorp Vault**.

## Quick commands

```bash
cp deploy/config.env.example deploy/config.env   # fill in values
make deploy-all                                  # full stack
make deploy-vercel                               # frontend + payments
make deploy-render                               # integration API
make deploy-akash                                # Vault-injected GPU workers
```

Equivalent shell entry:

```bash
./scripts/deploy-all.sh
./scripts/deploy-all.sh akash-bittensor   # requires BT_NETUID
./scripts/deploy-all.sh --dry-run
```

## Platform targets

| Target | Command | Artifact |
|--------|---------|----------|
| Full stack | `make deploy-all` | All steps in order |
| Vercel | `make deploy-vercel` | `vercel.json` routes |
| Render | `make deploy-render` | `render.yaml` blueprint |
| Akash agent | `make deploy-akash` | `deploy/deploy-swarm-monolith.yaml` |
| Akash Bittensor | `make deploy-akash-bittensor` | `deploy/akash-bittensor-miner.sdl.yml` |
| Akash Odysseus | `make deploy-akash-odysseus` | `deploy/akash/odysseus-vault.sdl.yml` |
| Akash backend | `make deploy-akash-backend` | `deploy/akash-backend.sdl.yml` |
| Azure | `make azure-apply` | `terraform/` |
| Vault | `make vault-bootstrap` | `vault/setup/` |

Lower-level orchestrator: `scripts/deploy-production.sh <target>`.

## Recommended order

1. **Vault** — `make vault-bootstrap` + `make seed-vault`
2. **Build** — `make build` (GHCR images)
3. **Akash** — `make deploy-akash` (wrapped SecretID injection)
4. **Frontend** — `make frontend` then `make deploy-vercel`
5. **Render** — connect `render.yaml` in dashboard
6. **Monitoring** — `make monitoring-up sovereign-up`

## Vault secret injection (Akash)

SDLs declare key-only env vars; deploy scripts mint wrapped SecretIDs:

```bash
export VAULT_ADDR=... VAULT_TOKEN=...
make deploy-akash
```

See `docs/VAULT_AKASH_RUNTIME.md`.

## Idempotency

- Re-running `deploy-all` skips Vault if `VAULT_TOKEN` unset
- Image build uses content tags; safe to rebuild
- Akash deploy creates new deployment sequence (dseq) each run
- Terraform apply is plan-guarded in `deploy/scripts/apply-terraform.sh`

## Related docs

- `PRODUCTION_SPINUP.md` — master runbook
- `PRODUCTION_READINESS.md` — sign-off checklist
- `docs/AKASH_DEPLOY.md` — Akash JWT + lease lifecycle
- `DEPLOY.md` — legacy 5-step pipeline (Makefile `make deploy`)

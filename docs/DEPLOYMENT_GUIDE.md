# YieldSwarm Deployment Guide (Akash + Terraform Cloud)

> **Termux / mobile setup:** See [`docs/TERMUX_ENVIRONMENT_SETUP.md`](TERMUX_ENVIRONMENT_SETUP.md) for pipx and `npm run dev` troubleshooting.

This repository now includes a minimal, real deployment path for:

1. Akash lease provisioning (`scripts/akash-deploy.sh` + `deploy/deploy-swarm-monolith.yaml`)
2. Terraform Cloud workspace execution (`HelixChainProd` / `Helixchainprod`) with Azure VMSS fallback resources

## 1) Prepare environment files

```bash
cp .env.example .env
cp deploy/terraform-tfc/terraform.tfvars.example deploy/terraform-tfc/terraform.tfvars
```

Fill in real values in `.env` and `deploy/terraform-tfc/terraform.tfvars` (never commit secrets).

## 2) Install required CLIs in Codespaces

Required:

- `provider-services` (Akash CLI)
- `terraform` (>= 1.6)
- `jq`

## 3) Akash deployment flow

The Akash script performs:

- Deployment transaction (`tx deployment create`)
- Bid discovery (`query market bid list`)
- Lease creation (`tx market lease create`)
- Manifest send (`send-manifest`)

Run it:

```bash
bash ./scripts/akash-deploy.sh
```

When prompted, set `AKASH_PROVIDER` after inspecting `.akash/bids.json`, then rerun.

## 4) Terraform Cloud flow

```bash
cd deploy/terraform-tfc
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Or use Makefile targets: `make tfc-setup tfc-init tfc-apply`

Terraform is configured for workspace:

- Organization: `HelixChainProd`
- Workspace: `Helixchainprod`

## 5) One-command helper

You can also use:

```bash
make deploy-all
```

This runs setup, Akash deployment script, Terraform init, and Terraform apply in sequence.

Or run the standalone script:

```bash
bash ./scripts/codespace-deploy.sh
```

## Security reminders

- Keep wallet imports and private keys inside terminal-only flows.
- Never paste secrets into chat prompts.
- Do not commit `.env` or `deploy/terraform-tfc/terraform.tfvars`.
- Optional minimal SDL for TFC testing: `deploy/akash/tfc-bootstrap.sdl.yml`
- Production SDL remains `deploy/deploy-swarm-monolith.yaml` (Vault-hardened).

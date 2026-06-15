# YieldSwarm v1/v2 Trident Layer35 Blueprint

This document is the architecture reference used by deployment-oriented prompts in this repo.

## Core framing

- Base lineage: `ARCHITECTURE/v1-to-v2-supercharge.md`
- Runtime objective: production Akash-first worker deployment with cloud fallback
- Governance objective: iterative progression toward sovereign automation milestones

## Deployment-critical truth

1. Akash is the primary GPU execution plane.
2. Terraform Cloud (`HelixChainProd` / `Helixchainprod`) is the control plane for fallback infra.
3. Azure VMSS is the first fallback target in Terraform.
4. Worker endpoints must be injectable into frontend runtime (`app/arena/page.tsx`) without code edits.

## System layers used by this repository

### Trident runtime

- Akash lease lifecycle: deploy -> bids -> lease -> manifest -> status
- Worker container bootstrap from `docker/Dockerfile.worker` and `docker/entrypoint.sh`

### Fallback runtime

- Terraform-managed Azure resource group, VNet/subnet, and Linux VMSS for GPU-capable fallback
- Placeholders reserved in tfvars for RunPod, Vultr, DigitalOcean, and GCP expansion

### Frontend runtime

- Arena page consumes worker URL list from `NEXT_PUBLIC_WORKER_URLS` and query string overrides
- Health probes for each worker endpoint

## Invariants

- No secrets committed.
- Wallet imports happen terminal-side only.
- Deployment scripts remain executable in GitHub Codespaces.

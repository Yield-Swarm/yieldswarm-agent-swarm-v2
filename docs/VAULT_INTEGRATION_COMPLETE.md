# Vault Integration — Completion Report

**Branch:** `cursor/vault-integration-complete-9c82`  
**Canonical path:** `vault/` only (do not merge `infra/vault/` duplicates)

## What was completed

| Component | Path | Status |
|-----------|------|--------|
| KV bootstrap | `vault/scripts/bootstrap.sh` | Idempotent AppRole + policies |
| Secret seeding | `vault/scripts/seed-secrets.sh` | Aligned to `cloud/*` + `runtime/*` paths |
| Pre-deploy validation | `vault/scripts/validate-secrets.sh` | **New** — paths, policies, AppRoles |
| Terraform Vault reads | `terraform/vault.tf` | Azure, RunPod, Vultr, DO, RPC |
| Terraform login | `terraform/scripts/vault-login.sh` | Wrapped SecretID → token |
| Akash runtime injection | `deploy/akash/entrypoint.sh` | AppRole → `/run/secrets/app.env` |
| Akash JWT auth | `deploy/akash/setup-auth.sh` | AEP-63/64 via `runtime/akash` |
| Akash full deploy | `deploy/akash/deploy-full.sh` | create → bids → lease → manifest |
| Health checks | `agents/health_server.py` | `/health` on :8080 |
| Operator runbook | `SECRETS.md` | Updated file layout |

## Path alignment fix

`seed-secrets.sh` now writes `cloud/azure` (not `providers/azure`) matching `terraform/vault.tf` and `SECRETS.md` §9.

Akash secrets live at `yieldswarm/runtime/akash` with JWT fields:
`auth_method`, `key_name`, `keyring_backend`, `wallet_mnemonic`, `rpc_endpoint`, `chain_id`, `gas_prices`.

## Quick start

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=<admin-token>

make vault-bootstrap
# export cloud + runtime env vars, then:
make seed-vault
make vault-validate

# Terraform
export VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/terraform/role-id)
export VAULT_WRAPPED_SECRET_ID=$(vault write -wrap-ttl=300s -f -field=wrapping_token auth/approle/role/terraform/secret-id)
source scripts/vault-login.sh
cd terraform && terraform init && terraform plan

# Akash (Codespace with funded wallet)
export VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
export VAULT_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)
make akash-verify-env
make deploy-akash-full
```

## Security

**Rotate immediately** any API keys pasted in chat or `.env` drafts (QuickNode, Pinata, Cloudflare, LLM keys, etc.). Store only in Vault via `make seed-vault`.

## Merge strategy

Merge this branch → `development` → `main`. Do not wholesale-merge stale `cursor/hashicorp-vault-integration-*` branches.

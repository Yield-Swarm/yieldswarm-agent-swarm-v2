# YieldSwarm global Azure infrastructure (packages/infra)

Production Terraform for multi-region redundancy. **No secrets in this directory.**

## Regions (defaults)

| Role | Env var | Default |
|------|---------|---------|
| Production cluster | `AZURE_PROD_LOCATION` | Australia East |
| Hot standby / Cosmos | `AZURE_BACKUP_LOCATION` | Japan East |
| DR replica | `AZURE_DR_LOCATION` | Indonesia Central |

## Usage

```bash
cd packages/infra
cp terraform.tfvars.example terraform.tfvars   # fill locally, never commit
terraform init
terraform plan
```

Inject `admin_ssh_public_key` from Vault or `TF_VAR_admin_ssh_public_key` at apply time.

## Key rotation

If API keys or SSH material appeared in chat or git history, rotate immediately and re-seed Vault (`docs/VAULT_ENV_INJECTION.md`).

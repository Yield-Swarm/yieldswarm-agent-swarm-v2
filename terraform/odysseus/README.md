# Odysseus Vault Terraform

This Terraform config manages the Vault access policy and JWT roles used by the
Odysseus deployment artifacts.

It intentionally does not read Odysseus application secrets with Terraform.
Reading secrets through Terraform would place them in state. Runtime containers,
GitHub Actions, and production deploy scripts read secrets directly from
HashiCorp Vault instead.

## Expected Vault KV paths

- `kv/data/yieldswarm/odysseus/runtime`
  - `ODYSSEUS_API_KEY`
  - `ODYSSEUS_MODEL_HOST`
  - `ODYSSEUS_MODEL_API_KEY`
- `kv/data/yieldswarm/odysseus/deploy`
  - `image_repository`
  - optional Akash transaction defaults such as `AKASH_NET`, `AKASH_CHAIN_ID`,
    `AKASH_NODE`, `AKASH_FEES`, and `AKASH_KEY_NAME`

## Example

```bash
terraform init
terraform apply \
  -var='vault_addr=https://vault.example.com' \
  -var='github_repository=owner/repo'
```

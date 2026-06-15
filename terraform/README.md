# YieldSwarm Infrastructure Terraform

This stack provisions Azure, RunPod, Vultr, DigitalOcean, and the RPC
secret bundle for all agent shards. **No cloud credentials live in this
repo, in your shell history, or in CI variables.** Every secret is read
from Vault at `terraform plan/apply` time.

## Authentication flow

```
operator / CI
    │
    │  1. vault write -wrap-ttl=300s -f auth/approle/role/terraform/secret-id
    │     → returns a single-use wrap token (VAULT_WRAPPED_SECRET_ID)
    ▼
./scripts/vault-login.sh
    │
    │  2. vault unwrap            → secret_id
    │  3. vault write approle/login role_id=… secret_id=…
    │                             → 30-min VAULT_TOKEN
    ▼
terraform plan / apply
    │
    │  4. data "vault_kv_secret_v2" "azure" / "runpod" / "vultr" / "digitalocean" / "rpc/*"
    │  5. providers consume those data sources
    ▼
Cloud APIs (Azure, RunPod, Vultr, DO)
```

## Files

| File                               | Purpose                                           |
| ---------------------------------- | ------------------------------------------------- |
| `versions.tf`                      | Required providers + remote (S3) state            |
| `variables.tf`                     | Inputs (env, regions, shard count, KV mount)     |
| `vault.tf`                         | All `data "vault_kv_secret_v2"` reads             |
| `providers.tf`                     | Cloud providers, each fed by Vault data sources  |
| `azure.tf`                         | RG, Log Analytics, Container Apps for agents     |
| `runpod.tf`                        | GraphQL pod deploys, API key from Vault          |
| `vultr.tf`                         | Cron-runner instances with Vault Agent bootstrap |
| `digitalocean.tf`                  | Dashboard droplets + firewall                    |
| `rpc.tf`                           | Sensitive `rpc_bundle` output for downstream     |
| `cloud-init/vault-bootstrap.tftpl` | Cloud-init that installs + starts Vault Agent    |
| `scripts/vault-login.sh`           | Exchange wrapped SecretID → VAULT_TOKEN          |

## Usage

```bash
# 0. Prerequisites: vault CLI, jq, terraform >= 1.6, your cloud CLIs.

# 1. Get yourself a wrapped SecretID (operator workstation, MFA-gated)
export VAULT_ADDR=https://vault.yieldswarm.io:8200
vault login -method=oidc                 # human auth via OIDC
WRAP_TOKEN=$(vault write -wrap-ttl=300s -force \
  -format=json auth/approle/role/terraform/secret-id \
  | jq -r '.wrap_info.token')

# 2. Hand WRAP_TOKEN to whoever / whatever is running terraform.
export VAULT_ROLE_ID=$(terraform -chdir=../vault/terraform-vault-config \
  output -raw approle_role_ids | jq -r '.terraform')
export VAULT_WRAPPED_SECRET_ID="${WRAP_TOKEN}"

# 3. Source vault-login.sh, which unwraps and logs in.
source ./scripts/vault-login.sh

# 4. Standard terraform flow.
terraform init -backend-config=backend.hcl
terraform plan  -out=plan.tfplan
terraform apply plan.tfplan
```

## What is NOT in this stack

* Vault server policies, mounts, AppRoles - those live in
  `../vault/terraform-vault-config` and are applied with a *different*
  short-lived token derived from the `admin` policy.
* Akash deployment SDL - lives in `../akash/`. Akash workloads use the
  `akash-runtime` AppRole and pull their own secrets through the
  in-container Vault Agent. Terraform never sees Akash workload secrets.

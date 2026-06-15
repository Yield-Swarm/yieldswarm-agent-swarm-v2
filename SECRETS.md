# Vault Secrets Setup

This repository uses HashiCorp Vault as the source of truth for cloud provider,
RPC, and Akash runtime secrets. Do not commit rendered manifests, `.env` files,
`.tfvars`, Terraform state, AppRole SecretIDs, or Vault tokens.

## Secret contract

The default KV v2 mount is `secret`. The integration expects these paths:

| Path | Required keys |
| --- | --- |
| `secret/azure` | `subscription_id`, `tenant_id`, `client_id`, `client_secret` |
| `secret/runpod` | `api_key` |
| `secret/vultr` | `api_key` |
| `secret/digitalocean` | `token` |
| `secret/rpc` | `SOLANA_RPC_URL`, `FAILOVER_RPC_LIST` |
| `secret/akash/runtime` | Runtime env vars consumed by the Akash workload |

Terraform reads Azure, RunPod, Vultr, DigitalOcean, and RPC secrets from Vault in
`infra/terraform` with Vault provider ephemeral KV v2 reads. The Akash container
reads `secret/akash/runtime` and `secret/rpc` at startup through
`akash/bin/entrypoint.sh`.

> Important: Ephemeral Vault reads keep these provider/RPC secret values out of
> Terraform state and plan files when used in provider configuration. If future
> resources need secret values, pass them only to provider configuration,
> write-only arguments, or other ephemeral contexts. Use an encrypted remote
> backend with strict IAM, versioning, and audit logs for all production state.

## Prerequisites

Install and authenticate these tools on the operator machine:

```bash
vault version      # Vault CLI compatible with your Vault server
terraform version  # Terraform >= 1.10 for ephemeral values
docker version
akash version
envsubst --version
```

On Debian or Ubuntu, install `envsubst` with:

```bash
sudo apt-get update
sudo apt-get install -y gettext-base
```

Set Vault connection details:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE=""
export VAULT_TOKEN="<bootstrap-or-admin-token>"
vault status
```

## 1. Bootstrap Vault engines, policies, and AppRoles

Run this once per Vault environment:

```bash
cd infra/vault
terraform init
terraform plan
terraform apply
cd ../..
```

Verify the mounts, policies, and roles:

```bash
vault secrets list
vault auth list
vault policy read yieldswarm-terraform-platform
vault policy read yieldswarm-akash-runtime
vault read auth/approle/role/yieldswarm-terraform
vault read auth/approle/role/yieldswarm-akash
```

## 2. Populate provider and RPC secrets

Disable shell history for the current shell before typing secret values:

```bash
set +o history 2>/dev/null || true
```

Write Azure credentials:

```bash
read -rp "Azure subscription ID: " AZURE_SUBSCRIPTION_ID
read -rp "Azure tenant ID: " AZURE_TENANT_ID
read -rp "Azure client ID: " AZURE_CLIENT_ID
read -rsp "Azure client secret: " AZURE_CLIENT_SECRET; echo

vault kv put secret/azure \
  subscription_id="$AZURE_SUBSCRIPTION_ID" \
  tenant_id="$AZURE_TENANT_ID" \
  client_id="$AZURE_CLIENT_ID" \
  client_secret="$AZURE_CLIENT_SECRET"

unset AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET
```

Write RunPod, Vultr, and DigitalOcean credentials:

```bash
read -rsp "RunPod API key: " RUNPOD_API_KEY; echo
vault kv put secret/runpod api_key="$RUNPOD_API_KEY"
unset RUNPOD_API_KEY

read -rsp "Vultr API key: " VULTR_API_KEY; echo
vault kv put secret/vultr api_key="$VULTR_API_KEY"
unset VULTR_API_KEY

read -rsp "DigitalOcean token: " DIGITALOCEAN_TOKEN; echo
vault kv put secret/digitalocean token="$DIGITALOCEAN_TOKEN"
unset DIGITALOCEAN_TOKEN
```

Write RPC endpoints and API keys. `FAILOVER_RPC_LIST` must be a JSON array
encoded as a string:

```bash
read -rsp "Solana RPC URL: " SOLANA_RPC_URL; echo
read -rsp "Failover RPC JSON array: " FAILOVER_RPC_LIST; echo
read -rsp "Helius API key (optional): " HELIUS_API_KEY; echo
read -rsp "Ethereum RPC URL (optional): " ETHEREUM_RPC_URL; echo
read -rsp "Base RPC URL (optional): " BASE_RPC_URL; echo
read -rsp "Arbitrum RPC URL (optional): " ARBITRUM_RPC_URL; echo

vault kv put secret/rpc \
  SOLANA_RPC_URL="$SOLANA_RPC_URL" \
  FAILOVER_RPC_LIST="$FAILOVER_RPC_LIST" \
  HELIUS_API_KEY="$HELIUS_API_KEY" \
  ETHEREUM_RPC_URL="$ETHEREUM_RPC_URL" \
  BASE_RPC_URL="$BASE_RPC_URL" \
  ARBITRUM_RPC_URL="$ARBITRUM_RPC_URL"

unset SOLANA_RPC_URL FAILOVER_RPC_LIST HELIUS_API_KEY ETHEREUM_RPC_URL BASE_RPC_URL ARBITRUM_RPC_URL
```

Write Akash runtime secrets. Add or remove keys to match the workload, but keep
keys valid as shell environment variable names (`A-Z`, `0-9`, and `_`, not
starting with a number):

```bash
read -rsp "AgentSwarm master key: " AGENTSWARM_MASTER_KEY; echo
read -rsp "Kimiclaw consensus key: " KIMICLAW_CONSENSUS_KEY; echo
read -rsp "Wallet encryption key: " WALLET_ENCRYPTION_KEY; echo
read -rsp "TEE signing key: " TEE_SIGNING_KEY; echo
read -rsp "Database encryption key: " DATABASE_ENCRYPTION_KEY; echo
read -rsp "OpenAI API key (optional): " OPENAI_API_KEY; echo
read -rsp "Anthropic API key (optional): " ANTHROPIC_API_KEY; echo

vault kv put secret/akash/runtime \
  AGENTSWARM_MASTER_KEY="$AGENTSWARM_MASTER_KEY" \
  KIMICLAW_CONSENSUS_KEY="$KIMICLAW_CONSENSUS_KEY" \
  WALLET_ENCRYPTION_KEY="$WALLET_ENCRYPTION_KEY" \
  TEE_SIGNING_KEY="$TEE_SIGNING_KEY" \
  DATABASE_ENCRYPTION_KEY="$DATABASE_ENCRYPTION_KEY" \
  OPENAI_API_KEY="$OPENAI_API_KEY" \
  ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

unset AGENTSWARM_MASTER_KEY KIMICLAW_CONSENSUS_KEY WALLET_ENCRYPTION_KEY TEE_SIGNING_KEY DATABASE_ENCRYPTION_KEY OPENAI_API_KEY ANTHROPIC_API_KEY
```

Re-enable shell history if desired:

```bash
set -o history 2>/dev/null || true
```

## 3. Run Terraform with Vault-sourced provider credentials

Use the Terraform AppRole to obtain a short-lived Vault token:

```bash
export TF_VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/yieldswarm-terraform/role-id)"
export TF_VAULT_SECRET_ID="$(vault write -field=secret_id -f auth/approle/role/yieldswarm-terraform/secret-id)"
export VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="$TF_VAULT_ROLE_ID" secret_id="$TF_VAULT_SECRET_ID")"
export TF_VAR_vault_kv_mount_path="secret"

cd infra/terraform
terraform init
terraform plan
cd ../..

unset TF_VAULT_ROLE_ID TF_VAULT_SECRET_ID TF_VAR_vault_kv_mount_path VAULT_TOKEN
```

If you use HCP Terraform, Terraform Cloud, Azure Storage, or another remote
backend, configure it before `terraform init`. The backend must encrypt state at
rest and restrict state read access to the smallest possible group. This stack
uses ephemeral Vault reads for provider credentials; keep any future use of
secret values in ephemeral or write-only contexts so that guarantee remains true.

## 4. Build and push the Akash image

Set the image reference for your registry, then build and push:

```bash
export AKASH_IMAGE="ghcr.io/<owner>/yieldswarm-akash:$(git rev-parse --short HEAD)"
docker build -f akash/Dockerfile -t "$AKASH_IMAGE" .
docker push "$AKASH_IMAGE"
```

## 5. Deploy Akash with runtime Vault injection

Create a one-use, short-lived wrapped AppRole SecretID immediately before
rendering and submitting the deployment. Do not commit the rendered YAML.

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE=""
export VAULT_KV_MOUNT="secret"
export VAULT_APPROLE_MOUNT="approle"
export VAULT_SECRET_PATHS="akash/runtime,rpc"
export VAULT_REVOKE_TOKEN_AFTER_LOAD="true"
export VAULT_EXPORT_TOKEN_TO_CHILD="false"
export VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/yieldswarm-akash/role-id)"
export VAULT_WRAP_TOKEN="$(vault write -field=wrapping_token -wrap-ttl=5m -f auth/approle/role/yieldswarm-akash/secret-id)"

export LOG_LEVEL="INFO"
export AKASH_CPU_UNITS="1"
export AKASH_MEMORY_SIZE="2Gi"
export AKASH_STORAGE_SIZE="10Gi"
export AKASH_DENOM="uakt"
export AKASH_BID_AMOUNT="1000"
export AKASH_REPLICA_COUNT="1"

envsubst < akash/deploy/deploy.yaml.tpl > /tmp/yieldswarm-akash.yaml
akash tx deployment create /tmp/yieldswarm-akash.yaml \
  --from "$AKASH_KEY_NAME" \
  --chain-id "$AKASH_CHAIN_ID" \
  --node "$AKASH_NODE" \
  --fees "$AKASH_FEES"

shred -u /tmp/yieldswarm-akash.yaml
unset VAULT_WRAP_TOKEN VAULT_ROLE_ID
```

The container entrypoint:

1. Unwraps the one-use Vault token or AppRole SecretID.
2. Logs in to Vault with the `yieldswarm-akash-runtime` policy.
3. Reads `secret/akash/runtime` and `secret/rpc`.
4. Exports those values into the workload process environment.
5. Removes temporary files and revokes/unsets the Vault token by default.

## 6. Rotate secrets

Patch a single key without rewriting the whole secret:

```bash
read -rsp "New RunPod API key: " RUNPOD_API_KEY; echo
vault kv patch secret/runpod api_key="$RUNPOD_API_KEY"
unset RUNPOD_API_KEY
```

Force Akash workloads to pick up rotated values by creating a new wrapped
SecretID and redeploying the SDL:

```bash
export VAULT_WRAP_TOKEN="$(vault write -field=wrapping_token -wrap-ttl=5m -f auth/approle/role/yieldswarm-akash/secret-id)"
envsubst < akash/deploy/deploy.yaml.tpl > /tmp/yieldswarm-akash.yaml
akash tx deployment update /tmp/yieldswarm-akash.yaml \
  --from "$AKASH_KEY_NAME" \
  --chain-id "$AKASH_CHAIN_ID" \
  --node "$AKASH_NODE" \
  --fees "$AKASH_FEES"
shred -u /tmp/yieldswarm-akash.yaml
unset VAULT_WRAP_TOKEN
```

## 7. Operational controls

- Enable Vault audit devices before production use:

  ```bash
  vault audit enable file file_path=/var/log/vault/audit.log
  ```

- Prefer CIDR-bound AppRole tokens in `infra/vault` variables:

  ```bash
  terraform apply \
    -var='terraform_token_bound_cidrs=["203.0.113.10/32"]' \
    -var='akash_token_bound_cidrs=["198.51.100.0/24"]'
  ```

- Keep `secret_id_num_uses = 1` and short `secret_id_ttl` values for Akash.
- Monitor Vault audit logs for reads of `secret/data/*` and AppRole logins.
- Never put provider credentials or RPC URLs in Akash SDL, Docker images,
  Terraform variables, CI logs, or shell history.

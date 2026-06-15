# HashiCorp Vault Secrets Setup

This repository stores no production secrets. Vault owns Azure, RunPod, Vultr,
DigitalOcean, RPC, and Akash runtime secrets; Terraform and Akash workloads read
only the Vault paths their policies allow.

## Secret layout

| Vault KV v2 path | Reader | Required keys |
| --- | --- | --- |
| `secret/terraform/azure` | Terraform | `subscription_id`, `tenant_id`, `client_id`, `client_secret`, `environment` |
| `secret/terraform/digitalocean` | Terraform | `token` |
| `secret/terraform/runpod` | Terraform modules/scripts | `api_key` |
| `secret/terraform/vultr` | Terraform | `api_key` |
| `secret/terraform/rpc` | Terraform and Akash runtime | `SOLANA_RPC_URL`, `HELIUS_API_KEY`, `FAILOVER_RPC_LIST` |
| `secret/runtime/akash` | Akash runtime | Runtime environment variables such as `AGENTSWARM_MASTER_KEY` |

Terraform data sources necessarily place fetched secrets in Terraform state.
Use an encrypted remote backend with restricted access for production plans and
never commit local `terraform.tfstate` files.

## 1. Bootstrap Vault engines, policies, and AppRoles

Run these commands from the repository root with a Vault administrator token:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE=""
vault status
vault login

cd infra/vault
terraform init
terraform apply \
  -var="vault_addr=${VAULT_ADDR}" \
  -var="vault_namespace=${VAULT_NAMESPACE}" \
  -auto-approve
cd ../..
```

This creates:

- KV v2 secrets engine at `secret/`
- Transit secrets engine at `transit/`
- `terraform-secrets-read` policy
- `akash-runtime` policy
- `terraform` AppRole
- `akash-runtime` AppRole

## 2. Write cloud and RPC secrets

The commands below keep values out of shell history by prompting for each secret.

```bash
read -rp "Azure subscription id: " AZURE_SUBSCRIPTION_ID
read -rp "Azure tenant id: " AZURE_TENANT_ID
read -rp "Azure client id: " AZURE_CLIENT_ID
read -rsp "Azure client secret: " AZURE_CLIENT_SECRET; echo
vault kv put secret/terraform/azure \
  subscription_id="${AZURE_SUBSCRIPTION_ID}" \
  tenant_id="${AZURE_TENANT_ID}" \
  client_id="${AZURE_CLIENT_ID}" \
  client_secret="${AZURE_CLIENT_SECRET}" \
  environment="public"
unset AZURE_CLIENT_SECRET

read -rsp "DigitalOcean token: " DIGITALOCEAN_TOKEN; echo
vault kv put secret/terraform/digitalocean token="${DIGITALOCEAN_TOKEN}"
unset DIGITALOCEAN_TOKEN

read -rsp "RunPod API key: " RUNPOD_API_KEY; echo
vault kv put secret/terraform/runpod api_key="${RUNPOD_API_KEY}"
unset RUNPOD_API_KEY

read -rsp "Vultr API key: " VULTR_API_KEY; echo
vault kv put secret/terraform/vultr api_key="${VULTR_API_KEY}"
unset VULTR_API_KEY

read -rsp "Solana RPC URL: " SOLANA_RPC_URL; echo
read -rsp "Helius API key: " HELIUS_API_KEY; echo
read -rsp "Failover RPC JSON list: " FAILOVER_RPC_LIST; echo
vault kv put secret/terraform/rpc \
  SOLANA_RPC_URL="${SOLANA_RPC_URL}" \
  HELIUS_API_KEY="${HELIUS_API_KEY}" \
  FAILOVER_RPC_LIST="${FAILOVER_RPC_LIST}"
unset SOLANA_RPC_URL HELIUS_API_KEY FAILOVER_RPC_LIST
```

Add extra RPC keys with the same path when needed:

```bash
vault kv patch secret/terraform/rpc ETHEREUM_RPC_URL="https://replace.example"
```

## 3. Write Akash runtime secrets

Store only environment variables that the container should receive at process
startup. The entrypoint validates variable names before exporting them.

```bash
read -rsp "AgentSwarm master key: " AGENTSWARM_MASTER_KEY; echo
read -rsp "Kimiclaw consensus key: " KIMICLAW_CONSENSUS_KEY; echo
read -rsp "Wallet encryption key: " WALLET_ENCRYPTION_KEY; echo
read -rsp "TEE signing key: " TEE_SIGNING_KEY; echo
read -rsp "Database encryption key: " DATABASE_ENCRYPTION_KEY; echo
read -rsp "OpenAI API key: " OPENAI_API_KEY; echo
read -rsp "Grok API key: " GROK_API_KEY; echo
vault kv put secret/runtime/akash \
  AGENTSWARM_MASTER_KEY="${AGENTSWARM_MASTER_KEY}" \
  KIMICLAW_CONSENSUS_KEY="${KIMICLAW_CONSENSUS_KEY}" \
  WALLET_ENCRYPTION_KEY="${WALLET_ENCRYPTION_KEY}" \
  TEE_SIGNING_KEY="${TEE_SIGNING_KEY}" \
  DATABASE_ENCRYPTION_KEY="${DATABASE_ENCRYPTION_KEY}" \
  OPENAI_API_KEY="${OPENAI_API_KEY}" \
  GROK_API_KEY="${GROK_API_KEY}"
unset AGENTSWARM_MASTER_KEY KIMICLAW_CONSENSUS_KEY WALLET_ENCRYPTION_KEY
unset TEE_SIGNING_KEY DATABASE_ENCRYPTION_KEY OPENAI_API_KEY GROK_API_KEY
```

Patch individual runtime keys during rotation:

```bash
read -rsp "New OpenAI API key: " OPENAI_API_KEY; echo
vault kv patch secret/runtime/akash OPENAI_API_KEY="${OPENAI_API_KEY}"
unset OPENAI_API_KEY
```

## 4. Run Terraform with a Vault-issued token

Use the Terraform AppRole instead of an administrator token:

```bash
export TF_VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/terraform/role-id)"
export TF_VAULT_SECRET_ID="$(vault write -field=secret_id -f auth/approle/role/terraform/secret-id)"
export VAULT_TOKEN="$(vault write -field=token auth/approle/login \
  role_id="${TF_VAULT_ROLE_ID}" \
  secret_id="${TF_VAULT_SECRET_ID}")"
unset TF_VAULT_SECRET_ID

cd infra/terraform
terraform init
terraform plan \
  -var="vault_addr=${VAULT_ADDR}" \
  -var="vault_namespace=${VAULT_NAMESPACE}"
cd ../..

unset VAULT_TOKEN TF_VAULT_ROLE_ID
```

The Terraform configuration reads:

- Azure provider credentials from `data.vault_kv_secret_v2.azure`
- DigitalOcean provider token from `data.vault_kv_secret_v2.digitalocean`
- Vultr provider key from `data.vault_kv_secret_v2.vultr`
- RunPod API key from `local.runpod_secrets`
- RPC values from `local.rpc_secrets`

Do not reintroduce provider credentials as Terraform variables or `.tfvars`.

## 5. Build and deploy the Akash workload

Build and push the image from the repository root:

```bash
export AKASH_IMAGE="registry.example.com/yieldswarm/akash-runtime:$(git rev-parse --short HEAD)"
docker build -f deploy/akash/Dockerfile -t "${AKASH_IMAGE}" .
docker push "${AKASH_IMAGE}"
```

Render the Akash SDL immediately before deployment with a one-use, short-lived
wrapped SecretID. The rendered file contains runtime auth material; keep it in
`/tmp`, deploy it promptly, and delete it.

```bash
export VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
export VAULT_WRAPPED_SECRET_ID="$(vault write -field=wrapping_token -wrap-ttl=10m \
  -f auth/approle/role/akash-runtime/secret-id)"

export VAULT_KV_MOUNT="secret"
export VAULT_AKASH_SECRET_PATH="runtime/akash"
export VAULT_RPC_SECRET_PATH="terraform/rpc"
export REQUIRED_RUNTIME_ENV="SOLANA_RPC_URL"

export AKASH_CPU_UNITS="1"
export AKASH_MEMORY_SIZE="1Gi"
export AKASH_STORAGE_SIZE="1Gi"
export AKASH_PRICE_UAKT="1000"
export AKASH_COUNT="1"

envsubst < deploy/akash/deploy.yaml.tpl > /tmp/yieldswarm-akash.yaml
chmod 0600 /tmp/yieldswarm-akash.yaml

akash tx deployment create /tmp/yieldswarm-akash.yaml \
  --from "${AKASH_KEY_NAME}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --fees 5000uakt \
  -y

rm -f /tmp/yieldswarm-akash.yaml
unset VAULT_ROLE_ID VAULT_WRAPPED_SECRET_ID
```

The container entrypoint supports these auth inputs:

- `VAULT_TOKEN_FILE` or `VAULT_TOKEN`
- `VAULT_WRAPPED_TOKEN_FILE` or `VAULT_WRAPPED_TOKEN`
- `VAULT_ROLE_ID_FILE`/`VAULT_ROLE_ID` plus `VAULT_SECRET_ID_FILE`/`VAULT_SECRET_ID`
- `VAULT_ROLE_ID_FILE`/`VAULT_ROLE_ID` plus `VAULT_WRAPPED_SECRET_ID_FILE`/`VAULT_WRAPPED_SECRET_ID`

Prefer file-based inputs where the scheduler supports secret mounts. For Akash
SDL, use the wrapped SecretID flow above.

## 6. Verify without printing secrets

```bash
vault kv metadata get secret/terraform/azure
vault kv metadata get secret/terraform/digitalocean
vault kv metadata get secret/terraform/runpod
vault kv metadata get secret/terraform/vultr
vault kv metadata get secret/terraform/rpc
vault kv metadata get secret/runtime/akash

vault token capabilities secret/data/terraform/azure
vault token capabilities secret/data/runtime/akash
```

Expected capabilities:

- Terraform AppRole token: `read` on `secret/data/terraform/*`
- Akash runtime token: `read` on `secret/data/runtime/akash` and `secret/data/terraform/rpc`

## Production guardrails

- Never commit `.env`, rendered Akash SDL, Terraform state, Vault tokens, RoleIDs,
  SecretIDs, wrapped tokens, or provider credentials.
- Rotate any value that was previously committed or shared in plaintext.
- Keep Vault audit logging enabled and alert on reads outside the expected paths.
- Use one-use SecretIDs and short wrapping TTLs for Akash deployments.
- Use separate Vault namespaces or clusters for staging and production.

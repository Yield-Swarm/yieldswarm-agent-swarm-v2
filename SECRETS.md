# Secrets and Vault Setup

This repository now expects production secrets to come from HashiCorp Vault.

The implementation added in this branch does four things:

1. Bootstraps Vault KV v2 mounts and least-privilege policies with Terraform.
2. Makes Terraform read Azure, RunPod, Vultr, DigitalOcean, and RPC credentials from Vault.
3. Makes the Akash workload fetch runtime secrets from Vault during container startup.
4. Keeps the rendered Akash SDL out of git so no deploy-time secret material is committed.

## Secret Layout

Use these Vault paths:

- `platform/prod/azure`
- `platform/prod/runpod`
- `platform/prod/vultr`
- `platform/prod/digitalocean`
- `platform/prod/rpc`
- `apps/agentswarm/prod`

The bootstrap Terraform stack creates:

- KV v2 mount `platform`
- KV v2 mount `apps`
- AppRole `terraform`
- AppRole `akash-runtime`
- policy `terraform`
- policy `akash-runtime`

## Prerequisites

Install and authenticate these tools on the operator machine:

- `vault`
- `terraform`
- `docker`
- `jq`
- `python3`
- `akash`

Set your Vault endpoint and bootstrap token before the first apply:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE="admin"
export VAULT_TOKEN="hvs.replace-me"
```

If you are not using Vault namespaces, remove `VAULT_NAMESPACE`.

## 1. Configure a Remote Terraform Backend

Do not run the platform Terraform stack with local state. The Vault data sources used by Terraform can land in state, so use an encrypted remote backend with strict access control.

This repo ships `backend.tf.example` files for both Terraform roots. Copy them into place and initialize them with your Azure Blob backend settings:

```bash
cp infra/terraform/bootstrap/backend.tf.example infra/terraform/bootstrap/backend.tf
cp infra/terraform/platform/backend.tf.example infra/terraform/platform/backend.tf
```

Bootstrap backend:

```bash
terraform -chdir=infra/terraform/bootstrap init \
  -backend-config="resource_group_name=replace-me" \
  -backend-config="storage_account_name=replace-me" \
  -backend-config="container_name=terraform-state" \
  -backend-config="key=agentswarm/vault-bootstrap.tfstate"
```

Platform backend:

```bash
terraform -chdir=infra/terraform/platform init \
  -backend-config="resource_group_name=replace-me" \
  -backend-config="storage_account_name=replace-me" \
  -backend-config="container_name=terraform-state" \
  -backend-config="key=agentswarm/platform-secrets.tfstate"
```

## 2. Bootstrap Vault Mounts, Policies, and AppRoles

Run the bootstrap stack:

```bash
terraform -chdir=infra/terraform/bootstrap apply \
  -var="application_name=agentswarm" \
  -var="environment=prod"
```

If Terraform or the Akash workload will always originate from fixed egress ranges, tighten the AppRoles with CIDR bindings:

```bash
terraform -chdir=infra/terraform/bootstrap apply \
  -var="application_name=agentswarm" \
  -var="environment=prod" \
  -var='terraform_secret_id_bound_cidrs=["203.0.113.10/32"]' \
  -var='terraform_token_bound_cidrs=["203.0.113.10/32"]' \
  -var='akash_secret_id_bound_cidrs=["198.51.100.0/24"]' \
  -var='akash_token_bound_cidrs=["198.51.100.0/24"]'
```

Read the generated AppRole role IDs:

```bash
vault read -field=role_id auth/approle/role/terraform/role-id
vault read -field=role_id auth/approle/role/akash-runtime/role-id
```

## 3. Write Platform Provider Secrets to Vault

Write Azure credentials:

```bash
vault kv put platform/prod/azure \
  subscription_id="00000000-0000-0000-0000-000000000000" \
  tenant_id="00000000-0000-0000-0000-000000000000" \
  client_id="00000000-0000-0000-0000-000000000000" \
  client_secret="replace-me"
```

Write the RunPod API key:

```bash
vault kv put platform/prod/runpod \
  api_key="replace-me"
```

Write the Vultr API key:

```bash
vault kv put platform/prod/vultr \
  api_key="replace-me"
```

Write the DigitalOcean token:

```bash
vault kv put platform/prod/digitalocean \
  token="dop_v1_replace-me"
```

Write RPC credentials:

```bash
vault kv put platform/prod/rpc \
  primary_url="https://rpc.provider.example" \
  websocket_url="wss://rpc.provider.example/ws" \
  auth_header="Bearer replace-me" \
  failover_urls='["https://rpc1.provider.example","https://rpc2.provider.example"]'
```

## 4. Write Runtime Application Secrets to Vault

The Akash container loads every key under `apps/agentswarm/prod` and exports them as environment variables immediately before starting the app.

At minimum, store the keys the workload requires to boot plus the provider-specific runtime values you do not want in the SDL:

```bash
vault kv put apps/agentswarm/prod \
  AGENTSWARM_MASTER_KEY="replace-me" \
  KIMICLAW_CONSENSUS_KEY="replace-me" \
  GROK_API_KEY="replace-me" \
  OPENAI_API_KEY="replace-me" \
  GEMINI_API_KEY="replace-me" \
  ANTHROPIC_API_KEY="replace-me" \
  WALLET_ENCRYPTION_KEY="replace-me" \
  TEE_SIGNING_KEY="replace-me" \
  DATABASE_ENCRYPTION_KEY="replace-me" \
  SOLANA_RPC_URL="https://rpc.provider.example" \
  HELIUS_API_KEY="replace-me" \
  BIRDEYE_API_KEY="replace-me" \
  JUPITER_API_KEY="replace-me" \
  RAYDIUM_API_KEY="replace-me" \
  PUMP_FUN_DEPLOY_KEY="replace-me" \
  TON_API_KEY="replace-me" \
  TAO_SUBNET_KEY="replace-me" \
  HELIX_CHAIN_BRIDGE_KEY="replace-me" \
  ZEC_SHIELDED_KEY="replace-me" \
  ERC4337_BUNDLER_KEY="replace-me" \
  GPU_CLUSTER_KEYS='["runpod-key-1"]' \
  DEPIN_HELIUM_HOTSPOT_KEYS='["hotspot-key-1"]' \
  GRASS_NODE_KEYS='["grass-node-1"]' \
  NOTION_API_KEY="replace-me" \
  LINEAR_API_KEY="replace-me" \
  VERCEL_API_TOKEN="replace-me" \
  GITHUB_TOKEN="replace-me" \
  FAILOVER_RPC_LIST='["https://rpc1.provider.example","https://rpc2.provider.example"]' \
  LOG_LEVEL="INFO"
```

To add or rotate individual runtime values later, use `vault kv patch`:

```bash
vault kv patch apps/agentswarm/prod \
  OPENAI_API_KEY="replace-me-rotated" \
  SOLANA_RPC_URL="https://new-rpc.provider.example"
```

## 5. Log Terraform into Vault and Verify Secret Reads

Create a short-lived SecretID for the Terraform AppRole, log in, and export the resulting Vault token:

```bash
export TERRAFORM_ROLE_ID="$(vault read -field=role_id auth/approle/role/terraform/role-id)"
export TERRAFORM_SECRET_ID="$(vault write -field=secret_id auth/approle/role/terraform/secret-id)"
export VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="${TERRAFORM_ROLE_ID}" secret_id="${TERRAFORM_SECRET_ID}")"
```

Now run a plan in the platform stack:

```bash
terraform -chdir=infra/terraform/platform plan \
  -var="application_name=agentswarm" \
  -var="environment=prod"
```

This stack configures these providers directly from Vault:

- `hashicorp/azurerm`
- `decentralized-infrastructure/runpod`
- `vultr/vultr`
- `digitalocean/digitalocean`

It also loads the RPC secret document into Terraform locals so downstream modules can use it without duplicating credential sources.

## 6. Build and Push the Akash Image

Build the image:

```bash
export AKASH_IMAGE="ghcr.io/replace-me/agentswarm-akash:$(git rev-parse --short HEAD)"
docker build -f infra/docker/akash/Dockerfile -t "${AKASH_IMAGE}" .
docker push "${AKASH_IMAGE}"
```

The image entrypoint at `infra/docker/akash/entrypoint.sh` does this on every container start:

1. unwraps a single-use Vault SecretID or uses a directly supplied Vault token
2. logs into Vault with AppRole
3. reads `apps/agentswarm/prod`
4. writes a local env file with mode `0600`
5. exports the secrets into the process environment
6. revokes the Vault token
7. starts the workload

## 7. Render a Short-Lived Akash SDL and Deploy

Akash SDL environment variables are visible in the manifest, so do not place long-lived secrets there. The pattern in this repo uses a wrapped, single-use SecretID with a short TTL and renders the final SDL locally immediately before deployment.

Read the Akash AppRole role ID:

```bash
export VAULT_APPROLE_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
```

Create a wrapped SecretID with a five-minute TTL:

```bash
export VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=5m -field=wrapping_token auth/approle/role/akash-runtime/secret-id)"
```

Render the SDL:

```bash
export AKASH_IMAGE="ghcr.io/replace-me/agentswarm-akash:$(git rev-parse --short HEAD)"
export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE="admin"
export VAULT_SECRET_PATH="agentswarm/prod"
export APP_START_COMMAND="python agents/akash-optimizer.py"
export VAULT_REQUIRED_SECRET_KEYS="AGENTSWARM_MASTER_KEY,OPENAI_API_KEY,SOLANA_RPC_URL"

chmod 0755 infra/scripts/render-akash-sdl.sh
infra/scripts/render-akash-sdl.sh
```

Deploy the rendered SDL immediately:

```bash
akash tx deployment create infra/akash/rendered/deployment.sdl.yaml \
  --from replace-me \
  --node https://rpc.provider.example:443 \
  --chain-id akashnet-2
```

Delete the rendered SDL as soon as the deployment is accepted:

```bash
rm -f infra/akash/rendered/deployment.sdl.yaml
unset VAULT_WRAPPED_SECRET_ID
```

## 8. Rotation Procedures

Rotate a provider secret:

```bash
vault kv patch platform/prod/runpod api_key="replace-me-rotated"
```

Rotate an application secret:

```bash
vault kv patch apps/agentswarm/prod OPENAI_API_KEY="replace-me-rotated"
```

Rotate the Akash SecretID issuance path without changing policy:

```bash
vault write -wrap-ttl=5m -field=wrapping_token auth/approle/role/akash-runtime/secret-id
```

Rotate the Terraform SecretID:

```bash
vault write -field=secret_id auth/approle/role/terraform/secret-id
```

## 9. Operational Guardrails

- Never commit `infra/akash/rendered/deployment.sdl.yaml`.
- Never store real values in `.env.example`, `*.tfvars`, or the SDL template.
- Prefer fixed egress CIDR bindings for both AppRoles whenever your network path supports it.
- Keep Vault TLS verification enabled. If your CA is private, set `VAULT_CACERT`.
- Use a remote, encrypted Terraform backend with limited access because Vault-derived values can appear in state.
- Keep the Akash wrapped SecretID TTL short and single-use.
- Re-render the SDL for each deployment instead of reusing old wrapped tokens.

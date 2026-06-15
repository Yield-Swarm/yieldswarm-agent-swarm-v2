# Secrets and HashiCorp Vault Setup

This repository does not store provider credentials, RPC URLs, API keys, or rendered Akash manifests. Vault is the source of truth for:

- Azure credentials
- RunPod API keys
- Vultr API keys
- DigitalOcean API tokens
- RPC endpoints and failover lists
- Runtime application secrets injected into Akash containers

## 1. Prerequisites

Run these commands from a trusted admin workstation with `vault`, `terraform`, `docker`, `envsubst`, and `akash` installed.

```sh
export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE=""

vault status
vault login -method=oidc
```

If your Vault does not use namespaces, keep `VAULT_NAMESPACE` empty.

## 2. Bootstrap Vault secret engines, policies, and AppRoles

```sh
terraform -chdir=infra/vault/bootstrap init
terraform -chdir=infra/vault/bootstrap apply \
  -var='kv_mount=secret' \
  -var='transit_mount=transit' \
  -var='approle_mount=approle'
```

Verify the expected Vault objects:

```sh
vault secrets list
vault auth list
vault policy read agentswarm-terraform
vault policy read agentswarm-akash-runtime
vault policy read agentswarm-secret-writer
```

## 3. Load cloud and RPC secrets into Vault

Create temporary JSON files with restrictive permissions, write them to KV v2, then destroy the local copies.

```sh
umask 077
SECRETS_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$SECRETS_TMP_DIR"' EXIT HUP INT TERM
```

### Azure

```sh
cat > "$SECRETS_TMP_DIR/azure.json" <<'JSON'
{
  "ARM_CLIENT_ID": "00000000-0000-0000-0000-000000000000",
  "ARM_CLIENT_SECRET": "replace-with-azure-client-secret",
  "ARM_TENANT_ID": "00000000-0000-0000-0000-000000000000",
  "ARM_SUBSCRIPTION_ID": "00000000-0000-0000-0000-000000000000"
}
JSON

vault kv put secret/cloud/azure @"$SECRETS_TMP_DIR/azure.json"
```

### RunPod

```sh
cat > "$SECRETS_TMP_DIR/runpod.json" <<'JSON'
{
  "RUNPOD_API_KEY": "replace-with-runpod-api-key"
}
JSON

vault kv put secret/cloud/runpod @"$SECRETS_TMP_DIR/runpod.json"
```

### Vultr

```sh
cat > "$SECRETS_TMP_DIR/vultr.json" <<'JSON'
{
  "VULTR_API_KEY": "replace-with-vultr-api-key"
}
JSON

vault kv put secret/cloud/vultr @"$SECRETS_TMP_DIR/vultr.json"
```

### DigitalOcean

```sh
cat > "$SECRETS_TMP_DIR/digitalocean.json" <<'JSON'
{
  "DIGITALOCEAN_TOKEN": "replace-with-digitalocean-token"
}
JSON

vault kv put secret/cloud/digitalocean @"$SECRETS_TMP_DIR/digitalocean.json"
```

### RPC endpoints

```sh
cat > "$SECRETS_TMP_DIR/rpc-mainnet.json" <<'JSON'
{
  "SOLANA_RPC_URL": "https://replace-with-solana-rpc.example",
  "ETHEREUM_RPC_URL": "https://replace-with-ethereum-rpc.example",
  "POLYGON_RPC_URL": "https://replace-with-polygon-rpc.example",
  "FAILOVER_RPC_LIST": "[\"https://replace-with-failover-1.example\",\"https://replace-with-failover-2.example\"]"
}
JSON

vault kv put secret/rpc/mainnet @"$SECRETS_TMP_DIR/rpc-mainnet.json"
```

### Akash runtime application secrets

Only use environment-compatible key names (`A-Z`, `0-9`, and `_`). The entrypoint skips invalid environment names and never logs values.

```sh
cat > "$SECRETS_TMP_DIR/app-agentswarm.json" <<'JSON'
{
  "AGENTSWARM_MASTER_KEY": "replace-with-master-key",
  "KIMICLAW_CONSENSUS_KEY": "replace-with-consensus-key",
  "GROK_API_KEY": "replace-with-grok-api-key",
  "OPENAI_API_KEY": "replace-with-openai-api-key",
  "ANTHROPIC_API_KEY": "replace-with-anthropic-api-key",
  "WALLET_ENCRYPTION_KEY": "replace-with-wallet-encryption-key",
  "DATABASE_ENCRYPTION_KEY": "replace-with-database-encryption-key"
}
JSON

vault kv put secret/app/agentswarm @"$SECRETS_TMP_DIR/app-agentswarm.json"
```

Destroy local secret files:

```sh
find "$SECRETS_TMP_DIR" -type f -exec shred -u {} \; 2>/dev/null || rm -rf "$SECRETS_TMP_DIR"
```

## 4. Run Terraform with Vault-sourced provider credentials

Create a short-lived Terraform Vault token using the Terraform AppRole:

```sh
export TF_VAULT_ROLE_NAME="$(terraform -chdir=infra/vault/bootstrap output -raw terraform_role_name)"
export TF_VAULT_ROLE_ID="$(terraform -chdir=infra/vault/bootstrap output -raw terraform_role_id)"
export TF_VAULT_SECRET_ID="$(vault write -f -field=secret_id "auth/approle/role/$TF_VAULT_ROLE_NAME/secret-id")"
export VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="$TF_VAULT_ROLE_ID" secret_id="$TF_VAULT_SECRET_ID")"

terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform plan
```

The Terraform root at `infra/terraform` reads:

- `secret/cloud/azure`
- `secret/cloud/runpod`
- `secret/cloud/vultr`
- `secret/cloud/digitalocean`
- `secret/rpc/mainnet`

Terraform modules should consume provider blocks and `local.rpc_endpoints`; do not add secrets to `.tfvars` files.

## 5. Build and deploy Akash with runtime Vault injection

Build and publish the Akash image:

```sh
export AKASH_IMAGE="ghcr.io/YOUR_ORG/agentswarm-akash:$(git rev-parse --short HEAD)"

docker build -f docker/akash/Dockerfile -t "$AKASH_IMAGE" .
docker push "$AKASH_IMAGE"
```

Create a one-use, short-lived wrapped AppRole SecretID for this deployment:

```sh
export AKASH_ROLE_NAME="$(terraform -chdir=infra/vault/bootstrap output -raw akash_runtime_role_name)"
export VAULT_ROLE_ID="$(terraform -chdir=infra/vault/bootstrap output -raw akash_runtime_role_id)"
export AKASH_VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=10m -field=wrapping_token "auth/approle/role/$AKASH_ROLE_NAME/secret-id")"
```

Render the Akash SDL from environment variables. The rendered file contains a short-lived wrapped token, so keep it out of git and delete it after submission.

```sh
export VAULT_AUTH_MOUNT="approle"
export VAULT_KV_MOUNT="secret"
export AKASH_VAULT_SECRET_PATHS="app/agentswarm,cloud/runpod,cloud/vultr,cloud/digitalocean,rpc/mainnet"
export VAULT_CONNECT_TIMEOUT="5"
export VAULT_MAX_TIME="20"
export LOG_LEVEL="INFO"

export AKASH_CPU_UNITS="2"
export AKASH_MEMORY_SIZE="4Gi"
export AKASH_STORAGE_SIZE="20Gi"
export AKASH_BID_PRICE_UAKT="1000"
export AKASH_REPLICA_COUNT="1"

envsubst < deploy/akash/deploy.tpl.yml > /tmp/agentswarm-akash.yml
chmod 600 /tmp/agentswarm-akash.yml
```

Deploy with Akash:

```sh
export AKASH_KEY_NAME="replace-with-akash-key-name"
export AKASH_NODE="https://rpc.akashnet.net:443"
export AKASH_CHAIN_ID="akashnet-2"

akash tx deployment create /tmp/agentswarm-akash.yml \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE" \
  --chain-id "$AKASH_CHAIN_ID" \
  --fees 5000uakt

shred -u /tmp/agentswarm-akash.yml 2>/dev/null || rm -f /tmp/agentswarm-akash.yml
unset AKASH_VAULT_WRAPPED_SECRET_ID
```

The container entrypoint unwraps the token once, logs in to Vault with AppRole, exports secret keys from `AKASH_VAULT_SECRET_PATHS`, unsets bootstrap credential variables, and then starts the workload command.

## 6. Rotation commands

Rotate a provider secret by writing a new KV version:

```sh
vault kv put secret/cloud/runpod RUNPOD_API_KEY="replace-with-new-runpod-api-key"
```

Redeploy Akash with a fresh wrapped SecretID after any runtime secret rotation:

```sh
export AKASH_ROLE_NAME="$(terraform -chdir=infra/vault/bootstrap output -raw akash_runtime_role_name)"
export AKASH_VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=10m -field=wrapping_token "auth/approle/role/$AKASH_ROLE_NAME/secret-id")"
envsubst < deploy/akash/deploy.tpl.yml > /tmp/agentswarm-akash.yml
akash tx deployment update /tmp/agentswarm-akash.yml \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE" \
  --chain-id "$AKASH_CHAIN_ID" \
  --fees 5000uakt
shred -u /tmp/agentswarm-akash.yml 2>/dev/null || rm -f /tmp/agentswarm-akash.yml
```

Revoke active Vault tokens for a compromised role:

```sh
vault token revoke -mode=orphan -prefix auth/approle/login
```

## 7. Local runtime verification without printing secrets

```sh
export AKASH_ROLE_NAME="$(terraform -chdir=infra/vault/bootstrap output -raw akash_runtime_role_name)"
export VAULT_ROLE_ID="$(terraform -chdir=infra/vault/bootstrap output -raw akash_runtime_role_id)"
export VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=10m -field=wrapping_token "auth/approle/role/$AKASH_ROLE_NAME/secret-id")"

docker run --rm \
  -e VAULT_ADDR \
  -e VAULT_NAMESPACE \
  -e VAULT_ROLE_ID \
  -e VAULT_WRAPPED_SECRET_ID \
  -e VAULT_KV_MOUNT=secret \
  -e AKASH_VAULT_SECRET_PATHS="app/agentswarm,cloud/runpod,rpc/mainnet" \
  "$AKASH_IMAGE" \
  python -c 'import os; assert os.environ["RUNPOD_API_KEY"]; assert os.environ["SOLANA_RPC_URL"]; print("Vault injection OK")'
```

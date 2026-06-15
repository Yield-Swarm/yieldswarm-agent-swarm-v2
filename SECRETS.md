# Secrets and Vault Setup

This repository now treats HashiCorp Vault as the source of truth for production secrets.

Use this guide to:

1. bootstrap Vault mounts, policies, and the Akash AppRole,
2. seed Azure, RunPod, Vultr, DigitalOcean, RPC, and runtime secrets,
3. make Terraform read those secrets from Vault, and
4. deploy the Akash workload with runtime-only secret injection.

## Prerequisites

Install these tools before you start:

- Vault CLI 1.21.7 or newer
- Terraform 1.6 or newer
- `jq`
- `envsubst` (from GNU gettext)
- Docker
- Akash `provider-services`

Production requirements:

- use an encrypted remote Terraform backend,
- restrict access to Terraform state,
- issue a short-lived Vault operator token instead of using a long-lived root token,
- rotate Akash AppRole SecretIDs for every deployment.

---

## 1. Bootstrap Vault mounts, policies, and AppRole

Export the Vault address and a bootstrap token with enough privileges to manage mounts, ACL policies, and auth backends:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="replace-with-bootstrap-token"
export TF_VAR_vault_addr="$VAULT_ADDR"
export TF_VAR_vault_token="$VAULT_TOKEN"
```

Initialize and apply the Vault Terraform stack in bootstrap mode:

```bash
cd /workspace/infra/terraform/vault
terraform init
terraform fmt -check -recursive
terraform validate
terraform apply -var='enable_secret_reads=false'
```

Inspect the non-secret bootstrap outputs:

```bash
terraform output vault_bootstrap
terraform output vault_secret_paths
```

Create a short-lived operator token bound to the new `terraform-operator` policy:

```bash
vault token create -policy=terraform-operator -orphan -period=24h
```

If you want Terraform to use that operator token instead of the bootstrap token for later runs:

```bash
export VAULT_TOKEN="replace-with-terraform-operator-token"
export TF_VAR_vault_token="$VAULT_TOKEN"
```

---

## 2. Seed Vault secrets

### 2.1 Azure provider credentials

```bash
vault kv put kv-platform/providers/azure \
  ARM_SUBSCRIPTION_ID="replace-me" \
  ARM_TENANT_ID="replace-me" \
  ARM_CLIENT_ID="replace-me" \
  ARM_CLIENT_SECRET="replace-me"
```

### 2.2 RunPod provider credentials

```bash
vault kv put kv-platform/providers/runpod \
  RUNPOD_API_KEY="replace-me"
```

### 2.3 Vultr provider credentials

```bash
vault kv put kv-platform/providers/vultr \
  VULTR_API_KEY="replace-me"
```

### 2.4 DigitalOcean provider credentials

```bash
vault kv put kv-platform/providers/digitalocean \
  DIGITALOCEAN_TOKEN="replace-me"
```

### 2.5 Shared RPC credentials

```bash
vault kv put kv-platform/rpc/shared \
  SOLANA_RPC_URL="https://your-primary-solana-rpc.example.com" \
  HELIUS_API_KEY="replace-me" \
  FAILOVER_RPC_LIST='["https://your-failover-rpc-1.example.com","https://your-failover-rpc-2.example.com"]'
```

### 2.6 Common application runtime secrets

```bash
vault kv put kv-runtime/application/common \
  AGENTSWARM_MASTER_KEY="replace-me" \
  OPENAI_API_KEY="replace-me" \
  ANTHROPIC_API_KEY="replace-me" \
  WALLET_ENCRYPTION_KEY="replace-me"
```

### 2.7 Akash workload runtime secrets

```bash
vault kv put kv-runtime/akash/optimizer \
  AKASH_NODE="https://rpc.akashnet.net:443" \
  AKASH_CHAIN_ID="akashnet-2" \
  AKASH_KEY_NAME="replace-me" \
  AKASH_ACCOUNT_ADDRESS="replace-me" \
  AKASH_GAS="auto" \
  AKASH_GAS_PRICES="0.025uakt" \
  AKASH_GAS_ADJUSTMENT="1.5"
```

Verify what was written without printing values:

```bash
vault kv metadata get kv-platform/providers/azure
vault kv metadata get kv-platform/providers/runpod
vault kv metadata get kv-platform/providers/vultr
vault kv metadata get kv-platform/providers/digitalocean
vault kv metadata get kv-platform/rpc/shared
vault kv metadata get kv-runtime/application/common
vault kv metadata get kv-runtime/akash/optimizer
```

---

## 3. Make Terraform read and validate the Vault-backed secrets

Re-run Terraform with secret reads enabled:

```bash
cd /workspace/infra/terraform/vault
terraform apply -var='enable_secret_reads=true'
```

That apply validates the required keys for:

- `kv-platform/providers/azure`
- `kv-platform/providers/runpod`
- `kv-platform/providers/vultr`
- `kv-platform/providers/digitalocean`
- `kv-platform/rpc/shared`

Export the Vault-backed provider environment variables for downstream Terraform stacks:

```bash
eval "$(terraform output -json | jq -r '.terraform_provider_environment.value | to_entries[] | "export \(.key)=\(.value|@sh)"' )"
```

Confirm the environment variables exist without printing their contents:

```bash
for name in ARM_SUBSCRIPTION_ID ARM_TENANT_ID ARM_CLIENT_ID ARM_CLIENT_SECRET RUNPOD_API_KEY VULTR_API_KEY DIGITALOCEAN_TOKEN SOLANA_RPC_URL HELIUS_API_KEY FAILOVER_RPC_LIST; do
  if [[ -n "${!name:-}" ]]; then
    echo "$name is set"
  else
    echo "$name is missing" >&2
    exit 1
  fi
done
```

Downstream Terraform stacks can now authenticate with:

- Azure via `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`
- RunPod via `RUNPOD_API_KEY`
- Vultr via `VULTR_API_KEY`
- DigitalOcean via `DIGITALOCEAN_TOKEN`
- RPC consumers via `SOLANA_RPC_URL`, `HELIUS_API_KEY`, `FAILOVER_RPC_LIST`

---

## 4. Build the Akash image with the Vault-aware entrypoint

Build the container:

```bash
cd /workspace
docker build -f deploy/akash/Dockerfile -t ghcr.io/<org>/yieldswarm-akash-optimizer:<tag> .
```

Push the container:

```bash
docker push ghcr.io/<org>/yieldswarm-akash-optimizer:<tag>
```

The image entrypoint does all of the following at runtime:

1. authenticates to Vault using AppRole,
2. reads each path in `VAULT_SECRET_PATHS`,
3. renders an env file at `/run/secrets/agentswarm.env`,
4. exports those variables into the process environment,
5. revokes the Vault token before starting the workload.

No application secret is hardcoded into the image or the SDL.

---

## 5. Generate the Akash AppRole credentials

Fetch the Akash AppRole `role_id`:

```bash
vault read -field=role_id auth/approle/role/akash-runtime/role-id
```

Generate a new SecretID for the deployment:

```bash
vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id
```

Export both values for the SDL render step:

```bash
export VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
export VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)"
```

If you use Vault Enterprise namespaces, export `VAULT_NAMESPACE`; otherwise leave it empty:

```bash
export VAULT_NAMESPACE=""
```

Choose the exact secret paths the workload should read:

```bash
export VAULT_SECRET_PATHS="kv-platform/providers/runpod,kv-platform/providers/vultr,kv-platform/providers/digitalocean,kv-platform/rpc/shared,kv-runtime/application/common,kv-runtime/akash/optimizer"
```

---

## 6. Render and deploy the Akash SDL

Set the image reference:

```bash
export AKASH_IMAGE="ghcr.io/<org>/yieldswarm-akash-optimizer:<tag>"
```

Load the Akash CLI environment from Vault so the deployment commands use the same runtime contract:

```bash
eval "$(vault kv get -format=json kv-runtime/akash/optimizer | jq -r '.data.data | to_entries[] | "export \(.key)=\(.value|@sh)"' )"
```

Render the SDL from the template:

```bash
envsubst < /workspace/deploy/akash/deployment.sdl.tmpl.yml > /tmp/yieldswarm-optimizer.sdl.yml
```

Create the Akash deployment:

```bash
RESULT="$(provider-services tx deployment create /tmp/yieldswarm-optimizer.sdl.yml \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE" \
  --chain-id "$AKASH_CHAIN_ID" \
  --gas "$AKASH_GAS" \
  --gas-prices "$AKASH_GAS_PRICES" \
  --gas-adjustment "$AKASH_GAS_ADJUSTMENT" \
  -y \
  --output json)"
```

Extract the deployment sequence number:

```bash
export AKASH_DSEQ="$(printf '%s' "$RESULT" | jq -r '.logs[0].events[] | select(.type=="akash.v1.EventDeploymentCreated") | .attributes[] | select(.key=="dseq") | .value')"
export AKASH_OWNER="$(provider-services keys show "$AKASH_KEY_NAME" -a)"
```

Review bids:

```bash
provider-services query market bid list \
  --owner "$AKASH_OWNER" \
  --dseq "$AKASH_DSEQ" \
  --node "$AKASH_NODE" \
  --output json | jq .
```

Select the first provider and create the lease:

```bash
export AKASH_PROVIDER="$(provider-services query market bid list \
  --owner "$AKASH_OWNER" \
  --dseq "$AKASH_DSEQ" \
  --node "$AKASH_NODE" \
  --output json | jq -r '.bids[0].bid.provider')"

provider-services tx market lease create \
  --dseq "$AKASH_DSEQ" \
  --provider "$AKASH_PROVIDER" \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE" \
  --chain-id "$AKASH_CHAIN_ID" \
  --gas "$AKASH_GAS" \
  --gas-prices "$AKASH_GAS_PRICES" \
  --gas-adjustment "$AKASH_GAS_ADJUSTMENT" \
  -y
```

Send the manifest:

```bash
provider-services send-manifest /tmp/yieldswarm-optimizer.sdl.yml \
  --dseq "$AKASH_DSEQ" \
  --provider "$AKASH_PROVIDER" \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE"
```

---

## 7. Rotation and recovery

Rotate the Akash SecretID before each deploy:

```bash
export VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)"
```

Rotate any provider secret with a new versioned write:

```bash
vault kv put kv-platform/providers/runpod \
  RUNPOD_API_KEY="replace-with-new-value"
```

Re-run the validation/export apply after any secret contract change:

```bash
cd /workspace/infra/terraform/vault
terraform apply -var='enable_secret_reads=true'
```

Re-render the SDL after any AppRole credential change:

```bash
envsubst < /workspace/deploy/akash/deployment.sdl.tmpl.yml > /tmp/yieldswarm-optimizer.sdl.yml
```

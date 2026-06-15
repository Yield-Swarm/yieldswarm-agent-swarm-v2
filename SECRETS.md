# Vault Secrets Setup (Production)

This guide configures HashiCorp Vault as the only source of truth for:

- Azure credentials
- RunPod credentials
- Vultr credentials
- DigitalOcean credentials
- Shared RPC endpoints/keys
- Akash runtime application secrets

No credentials are hardcoded in Terraform, Docker images, or Akash manifests.

## 1) Prerequisites

Install the required CLIs:

```bash
# Vault CLI
vault --version

# Terraform
terraform --version

# jq + curl
jq --version
curl --version
```

Set Vault admin/bootstrap access:

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="<vault-bootstrap-or-admin-token>"
```

## 2) Bootstrap Vault engines, policies, and AppRoles

Run the repository bootstrap script:

```bash
chmod 0755 infra/vault/bootstrap.sh
./infra/vault/bootstrap.sh
```

This script:

- Enables `cloud`, `rpc`, and `app` kv-v2 secret engines (idempotent)
- Enables AppRole auth (idempotent)
- Writes:
  - `terraform-read` policy
  - `akash-runtime` policy
- Creates/updates AppRoles:
  - `terraform-read`
  - `akash-runtime`

## 3) Write provider and RPC secrets into Vault

Write Azure credentials:

```bash
vault kv put cloud/azure \
  client_id="<azure-client-id>" \
  client_secret="<azure-client-secret>" \
  tenant_id="<azure-tenant-id>" \
  subscription_id="<azure-subscription-id>"
```

Write RunPod credentials:

```bash
vault kv put cloud/runpod \
  api_key="<runpod-api-key>"
```

Write Vultr credentials:

```bash
vault kv put cloud/vultr \
  api_key="<vultr-api-key>"
```

Write DigitalOcean credentials:

```bash
vault kv put cloud/digitalocean \
  token="<digitalocean-token>"
```

Write shared RPC credentials:

```bash
vault kv put rpc/default \
  primary_url="https://rpc.provider.example" \
  websocket_url="wss://rpc.provider.example/ws" \
  api_key="<rpc-api-key>"
```

Write Akash runtime app secrets (example keys only):

```bash
vault kv put app/akash \
  OPENAI_API_KEY="<openai-key>" \
  GROK_API_KEY="<grok-key>" \
  HELIUS_API_KEY="<helius-key>"
```

## 4) Generate short-lived AppRole credentials

Terraform role:

```bash
export TERRAFORM_VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/terraform-read/role-id)"
export TERRAFORM_VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/terraform-read/secret-id)"
```

Akash runtime role:

```bash
export AKASH_VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
export AKASH_VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)"
```

## 5) Terraform: read all cloud/RPC credentials from Vault

Log in with Terraform AppRole and export token for Terraform only:

```bash
export TF_VAR_vault_addr="${VAULT_ADDR}"
export TF_VAR_vault_token="$(
  vault write -field=token auth/approle/login \
    role_id="${TERRAFORM_VAULT_ROLE_ID}" \
    secret_id="${TERRAFORM_VAULT_SECRET_ID}"
)"
```

Run Terraform:

```bash
cd infra/terraform
terraform init
terraform validate
terraform plan
cd ../..
```

Remove token from shell when finished:

```bash
unset TF_VAR_vault_token
```

## 6) Build and deploy the Akash image with runtime Vault injection

Build container image:

```bash
docker build -f infra/akash/Dockerfile -t ghcr.io/your-org/yieldswarm:vault-runtime .
docker push ghcr.io/your-org/yieldswarm:vault-runtime
```

Prepare deployment variables:

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_NAMESPACE=""
export AKASH_VAULT_ROLE_ID="${AKASH_VAULT_ROLE_ID}"
export AKASH_VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)"
```

Render and deploy SDL without hardcoded secrets:

```bash
envsubst < infra/akash/deployment.yaml > /tmp/akash-deployment.rendered.yaml

provider-services tx deployment create /tmp/akash-deployment.rendered.yaml \
  --from "${AKASH_KEY_NAME}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --fees 5000uakt \
  --yes

shred -u /tmp/akash-deployment.rendered.yaml
```

## 7) Security checks before production rollout

Verify policies:

```bash
vault policy read terraform-read
vault policy read akash-runtime
```

Verify mounts are kv-v2:

```bash
vault secrets list -detailed | rg 'cloud/|rpc/|app/'
```

Verify Terraform policy is read-only by capability check:

```bash
vault token capabilities "${TF_VAR_vault_token}" cloud/data/azure
vault token capabilities "${TF_VAR_vault_token}" cloud/metadata
```

Expected:

- `cloud/data/*` and `rpc/data/*` => `read`
- metadata paths => `list`
- no `create`, `update`, or `delete`

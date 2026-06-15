# Secrets and Vault Setup (Production)

This repo now expects all cloud and RPC credentials to come from HashiCorp Vault at runtime.
No provider key should be hardcoded in Terraform, Dockerfiles, manifests, or committed env files.

## 0) Prerequisites

Install required CLIs:

```bash
# Vault and jq are required for Vault bootstrap and runtime scripts.
vault --version
jq --version

# Terraform for infrastructure runs.
terraform --version

# Akash deployment flow
provider-services version
```

Set your Vault admin session:

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="<root-or-platform-admin-token>"
```

## 1) Bootstrap Vault mounts, policies, and AppRoles

Run once per environment:

```bash
chmod 750 infrastructure/vault/bootstrap.sh
./infrastructure/vault/bootstrap.sh
```

This script creates:

- kv-v2 mount: `kv-infra`
- kv-v2 mount: `kv-runtime`
- policy: `terraform-read`
- policy: `akash-runtime`
- AppRole: `terraform-ci`
- AppRole: `akash-runtime`

## 2) Write provider secrets to Vault

### 2.1 Infrastructure provider credentials (`kv-infra`)

```bash
vault kv put kv-infra/providers/azure \
  client_id="<azure-client-id>" \
  client_secret="<azure-client-secret>" \
  tenant_id="<azure-tenant-id>" \
  subscription_id="<azure-subscription-id>"

vault kv put kv-infra/providers/runpod \
  api_key="<runpod-api-key>"

vault kv put kv-infra/providers/vultr \
  api_key="<vultr-api-key>"

vault kv put kv-infra/providers/digitalocean \
  token="<digitalocean-token>"

vault kv put kv-infra/rpc/endpoints \
  primary_url="https://rpc-mainnet.example.com" \
  failover_urls_json='["https://rpc-failover-1.example.com","https://rpc-failover-2.example.com"]'
```

### 2.2 Runtime secrets for Akash containers (`kv-runtime`)

`deploy/akash/entrypoint.sh` exports every key under `kv-runtime/akash/runtime` into the process environment.

```bash
vault kv put kv-runtime/akash/runtime \
  RUNPOD_API_KEY="<runpod-api-key>" \
  VULTR_API_KEY="<vultr-api-key>" \
  DIGITALOCEAN_TOKEN="<digitalocean-token>" \
  PRIMARY_RPC_URL="https://rpc-mainnet.example.com"
```

## 3) Terraform: read secrets from Vault and plan/apply

Create a short-lived Terraform AppRole secret ID and login token:

```bash
export TF_VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/terraform-ci/role-id)"
export TF_VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/terraform-ci/secret-id)"
export TF_VAR_vault_address="$VAULT_ADDR"
export TF_VAR_vault_token="$(
  vault write -format=json auth/approle/login \
    role_id="$TF_VAULT_ROLE_ID" \
    secret_id="$TF_VAULT_SECRET_ID" | jq -r '.auth.client_token'
)"
```

Run Terraform:

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

Revoke the token after use:

```bash
vault token revoke "$TF_VAR_vault_token"
unset TF_VAULT_SECRET_ID TF_VAR_vault_token
```

## 4) Build and deploy Akash workload with runtime Vault injection

Build and push image:

```bash
docker build -f deploy/akash/Dockerfile -t ghcr.io/yieldswarm/akash-optimizer:<image-tag> .
docker push ghcr.io/yieldswarm/akash-optimizer:<image-tag>
```

Create one-time runtime AppRole secret ID:

```bash
export IMAGE_TAG="<image-tag>"
export VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
export VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)"
```

Render deployment manifest with environment substitution:

```bash
chmod 750 deploy/akash/render-manifest.sh
./deploy/akash/render-manifest.sh
```

Deploy to Akash:

```bash
provider-services tx deployment create deploy/akash/deployment.rendered.yaml \
  --from <wallet-name> \
  --chain-id <akash-chain-id> \
  --node <akash-rpc-node> \
  --fees 5000uakt \
  --gas auto \
  --yes
```

Immediately rotate or revoke `VAULT_SECRET_ID` after deployment:

```bash
unset VAULT_SECRET_ID
```

## 5) Security controls checklist

- Use short-lived AppRole secret IDs (`secret_id_ttl`) and rotate often.
- Never commit rendered manifests containing temporary credentials.
- Restrict network egress from Akash workloads to Vault and required APIs only.
- Enable Vault audit logging and alert on policy/auth changes.
- Use separate Vault namespaces/mounts per environment (dev/stage/prod).

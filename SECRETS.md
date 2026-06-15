# Secrets and Vault Setup (Production)

This project now uses HashiCorp Vault as the single source of truth for cloud and runtime secrets.

- No cloud/API credentials are committed to git.
- Terraform reads provider credentials from Vault KV v2.
- Akash workloads fetch runtime secrets from Vault at container start via AppRole.

## 1) Prerequisites

```bash
vault --version
terraform version
docker --version
provider-services version
```

Set Vault address and authenticate as an operator:

```bash
export VAULT_ADDR="https://vault.example.com"
vault login
```

If you use Vault Enterprise namespaces:

```bash
export VAULT_NAMESPACE="platform/prod"
```

## 2) Bootstrap Vault mounts, policies, and AppRoles

Run the idempotent bootstrap script from repo root:

```bash
./infra/vault/bootstrap-vault.sh
```

The script does all of the following:

- Ensures KV v2 mounts exist at `cloud-secrets/` and `app-secrets/`
- Ensures `approle/` auth is enabled
- Writes policies:
  - `terraform-cloud-read`
  - `akash-runtime-read`
- Configures AppRoles:
  - `terraform-ci` (short-lived token for Terraform runs)
  - `akash-runtime` (runtime secret reads)
- Prints each role ID and a wrapped secret-id token

Unwrap any wrapped secret-id token immediately on a secure machine:

```bash
vault unwrap <WRAPPED_SECRET_ID_TOKEN>
```

## 3) Write Terraform cloud credentials into Vault

Azure:

```bash
vault kv put cloud-secrets/terraform/azure \
  subscription_id="<azure-subscription-id>" \
  tenant_id="<azure-tenant-id>" \
  client_id="<azure-client-id>" \
  client_secret="<azure-client-secret>"
```

RunPod:

```bash
vault kv put cloud-secrets/terraform/runpod \
  api_key="<runpod-api-key>"
```

Vultr:

```bash
vault kv put cloud-secrets/terraform/vultr \
  api_key="<vultr-api-key>"
```

DigitalOcean:

```bash
vault kv put cloud-secrets/terraform/digitalocean \
  token="<digitalocean-token>"
```

RPC:

```bash
vault kv put cloud-secrets/terraform/rpc \
  primary_url="<primary-rpc-url>" \
  backup_url="<backup-rpc-url>"
```

## 4) Write Akash runtime secrets into Vault

Store runtime env vars under one KV document:

```bash
vault kv put app-secrets/akash/runtime \
  OPENAI_API_KEY="<openai-key>" \
  GROK_API_KEY="<grok-key>" \
  HELIUS_API_KEY="<helius-key>" \
  SOLANA_RPC_URL="<solana-rpc-url>"
```

Add additional keys as needed. Every key becomes an environment variable at runtime.

## 5) Terraform: login with AppRole and run

Get Terraform AppRole credentials:

```bash
export TF_VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/terraform-ci/role-id)"
export TF_VAULT_SECRET_ID="$(vault write -field=secret_id -f auth/approle/role/terraform-ci/secret-id)"
```

Exchange AppRole credentials for a short-lived Vault token:

```bash
export VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="$TF_VAULT_ROLE_ID" secret_id="$TF_VAULT_SECRET_ID")"
```

Run Terraform:

```bash
cd infra/terraform
terraform init
terraform plan -var="vault_addr=$VAULT_ADDR"
terraform apply -var="vault_addr=$VAULT_ADDR"
```

If using Enterprise namespaces, also pass:

```bash
terraform plan \
  -var="vault_addr=$VAULT_ADDR" \
  -var="vault_namespace=$VAULT_NAMESPACE"
```

## 6) Build and deploy Akash image

Build and push image:

```bash
docker build -f deploy/akash/Dockerfile -t ghcr.io/<org>/<repo>:vault-runtime .
docker push ghcr.io/<org>/<repo>:vault-runtime
```

Generate Akash runtime AppRole credentials:

```bash
export VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
export VAULT_SECRET_ID="$(vault write -field=secret_id -f auth/approle/role/akash-runtime/secret-id)"
```

Render SDL with environment substitution (no hardcoded secrets):

```bash
export AKASH_IMAGE="ghcr.io/<org>/<repo>:vault-runtime"
envsubst < deploy/akash/deployment.sdl.yml > /tmp/akash.deployment.sdl.yml
```

Deploy:

```bash
provider-services tx deployment create /tmp/akash.deployment.sdl.yml \
  --from "<akash-wallet-name>" \
  --node "https://rpc.akashnet.net:443" \
  --chain-id "akashnet-2" \
  --fees "5000uakt" \
  --gas "auto" \
  -y
```

## 7) Rotation and operational hygiene

Rotate Terraform secret-id (recommended for each CI run):

```bash
vault write -field=secret_id -f auth/approle/role/terraform-ci/secret-id
```

Rotate Akash runtime secret-id:

```bash
vault write -field=secret_id -f auth/approle/role/akash-runtime/secret-id
```

Rotate specific secret values:

```bash
vault kv put cloud-secrets/terraform/runpod api_key="<new-runpod-api-key>"
vault kv put app-secrets/akash/runtime OPENAI_API_KEY="<new-openai-key>"
```

## 8) Security requirements (must follow)

1. Never commit `.env` files with real credentials.
2. Use short-lived Vault tokens and secret IDs.
3. Restrict operator access to Vault policies and auth paths.
4. Store Terraform state in an encrypted remote backend.
5. Treat all CI logs and Akash deployment artifacts as sensitive.

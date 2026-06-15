# Production Secrets Setup (Vault + Terraform + Akash)

This repository is configured so secrets are pulled from HashiCorp Vault at
plan/apply time (Terraform) and at container startup (Akash runtime).

No provider/API secrets should be committed to git, baked into images, or
written to plaintext config files.

## 1) Prerequisites

Install these CLIs on your operator workstation or CI runner:

- `vault` (>= 1.15)
- `terraform` (>= 1.6)
- `docker`
- `provider-services` (Akash CLI)

Set Vault environment variables:

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="<bootstrap-admin-token>"
# Optional (Vault Enterprise):
export VAULT_NAMESPACE="admin"
```

## 2) Bootstrap Vault engines, policies, and auth roles with Terraform

From repo root:

```bash
cd infra/terraform/vault
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with the real Vault address/token/namespace, then run:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var="read_runtime_secrets=false" -out tfplan
terraform apply tfplan
```

This config does all of the following:

- Enables KV-v2 engines at `cloud/` and `rpc/`
- Creates a Terraform read policy for Azure/RunPod/Vultr/DO/RPC paths
- Creates an Akash runtime read policy
- Creates AppRole `terraform-ci`
- Enables Kubernetes auth backend and creates role `akash-runtime`

## 3) Write cloud and RPC secrets into Vault

Run these exact commands (replace placeholder values):

```bash
vault kv put cloud/azure \
  subscription_id="<azure-subscription-id>" \
  tenant_id="<azure-tenant-id>" \
  client_id="<azure-client-id>" \
  client_secret="<azure-client-secret>"

vault kv put cloud/runpod \
  api_key="<runpod-api-key>"

vault kv put cloud/vultr \
  api_key="<vultr-api-key>"

vault kv put cloud/digitalocean \
  token="<digitalocean-token>"

vault kv put rpc/rpc \
  solana_primary_url="https://<solana-rpc-endpoint>" \
  ethereum_primary_url="https://<ethereum-rpc-endpoint>" \
  fallback_urls_json='["https://<rpc-1>","https://<rpc-2>"]'
```

After writing secrets, run Terraform again to force read-time validation and
state wiring for Azure/RunPod/Vultr/DO/RPC:

```bash
terraform plan -out tfplan
terraform apply tfplan
```

## 4) Configure Vault Kubernetes auth backend (required for Akash runtime login)

If this is a fresh Vault cluster, configure the Kubernetes backend once:

```bash
vault write auth/kubernetes/config \
  kubernetes_host="https://<kubernetes-api-host>:443" \
  kubernetes_ca_cert=@/path/to/cluster-ca.crt \
  token_reviewer_jwt="<token-reviewer-jwt>"
```

Verify role:

```bash
vault read auth/kubernetes/role/akash-runtime
```

## 5) Configure Terraform CI to read secrets from Vault (AppRole)

Generate AppRole credentials for CI:

```bash
vault read auth/approle/role/terraform-ci/role-id
vault write -f auth/approle/role/terraform-ci/secret-id
```

Set these in your CI secret store (never in git):

- `VAULT_ADDR`
- `VAULT_ROLE_ID`
- `VAULT_SECRET_ID`
- `VAULT_NAMESPACE` (if used)

## 6) Build and publish Akash optimizer image

From repo root:

```bash
IMAGE_TAG="$(git rev-parse --short HEAD)"
docker build -f deploy/akash/Dockerfile -t ghcr.io/<org>/yieldswarm-akash-optimizer:${IMAGE_TAG} .
docker push ghcr.io/<org>/yieldswarm-akash-optimizer:${IMAGE_TAG}
```

Update `deploy/akash/deployment.yaml` to use the pushed tag.

## 7) Deploy to Akash (runtime secret injection)

The deployment file intentionally contains only Vault connection metadata and
secret path mappings (`VAULT_SECRET_EXPORTS`), never raw secret values.

Create the deployment:

```bash
provider-services tx deployment create deploy/akash/deployment.yaml \
  --from <wallet-name> \
  --node https://rpc.akashnet.net:443 \
  --chain-id akashnet-2 \
  --gas auto \
  --gas-adjustment 1.15 \
  --yes
```

## 8) Runtime behavior summary

- `deploy/akash/entrypoint.sh` authenticates to Vault at startup.
- It resolves all mappings in `VAULT_SECRET_EXPORTS`.
- It exports secrets into process environment in-memory only.
- It does **not** print secret values.
- `agents/akash-optimizer.py` exits non-zero if required secrets are missing.

## 9) Operational hardening checklist

Run these after initial bring-up:

```bash
vault audit enable file file_path=/var/log/vault_audit.log
```

Also enforce:

- TLS for Vault (`https://` only)
- short-lived tokens (already configured on AppRole)
- secret rotation playbooks for all providers
- CI masking for all `VAULT_*` and cloud credentials

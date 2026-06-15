# Production Secrets Setup (Vault + Terraform + Akash)

This repository now expects **all cloud and RPC secrets** to come from HashiCorp Vault.
No secret values should be committed into Git, `.env` files, Dockerfiles, or Akash SDL files.

## 1) Prerequisites

- Vault server reachable from your workstation/CI
- `vault` CLI installed and authenticated as an operator
- Terraform `>= 1.6`
- `akash` CLI (for Akash deployment)
- `envsubst` (from `gettext`) for SDL template rendering

Export operator session values:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="<vault-operator-token>"
```

## 2) Bootstrap Vault engines, policies, and AppRoles

From repo root:

```bash
chmod +x infra/vault/setup-vault.sh
./infra/vault/setup-vault.sh
```

What this script does:

1. Enables KV v2 secrets engine at `kv/` (if missing)
2. Enables `approle` auth method (if missing)
3. Writes least-privilege policies:
   - `terraform-read` (read-only to `kv/infra/providers/*`)
   - `akash-runtime` (read-only to `kv/runtime/akash/*`)
4. Creates AppRoles:
   - `terraform-reader`
   - `akash-runtime`

## 3) Write provider and RPC secrets into Vault

Use the exact paths expected by Terraform:

```bash
vault kv put kv/infra/providers/prod/azure \
  subscription_id="<azure-subscription-id>" \
  tenant_id="<azure-tenant-id>" \
  client_id="<azure-client-id>" \
  client_secret="<azure-client-secret>"

vault kv put kv/infra/providers/prod/runpod \
  api_key="<runpod-api-key>"

vault kv put kv/infra/providers/prod/vultr \
  api_key="<vultr-api-key>"

vault kv put kv/infra/providers/prod/digitalocean \
  token="<digitalocean-token>"

vault kv put kv/infra/providers/prod/rpc \
  primary_url="<primary-rpc-url>" \
  failover_json='["https://rpc1.example.com","https://rpc2.example.com"]'
```

Write runtime secrets for Akash entrypoint injection:

```bash
vault kv put kv/runtime/akash/prod \
  AGENTSWARM_MASTER_KEY="<master-key>" \
  SOLANA_RPC_URL="<solana-rpc-url>" \
  RUNPOD_API_KEY="<runpod-api-key>" \
  VULTR_API_KEY="<vultr-api-key>" \
  DIGITALOCEAN_TOKEN="<digitalocean-token>"
```

## 4) Generate short-lived credentials for Terraform

```bash
export TERRAFORM_ROLE_ID="$(vault read -field=role_id auth/approle/role/terraform-reader/role-id)"
export TERRAFORM_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/terraform-reader/secret-id)"
export VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="$TERRAFORM_ROLE_ID" secret_id="$TERRAFORM_SECRET_ID")"
```

Run Terraform with Vault-backed secrets:

```bash
cd infra/terraform
terraform init
terraform plan \
  -var "vault_addr=$VAULT_ADDR" \
  -var "environment=prod"
```

`terraform_data.secrets_contract` will fail the plan if any required key is missing.

## 5) Build and publish Akash image

```bash
docker build -f deploy/akash/Dockerfile -t "<registry>/akash-optimizer:prod" .
docker push "<registry>/akash-optimizer:prod"
```

## 6) Deploy to Akash with runtime Vault injection

Generate AppRole credentials for Akash runtime:

```bash
export AKASH_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
export AKASH_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)"
```

Set deploy-time variables and submit:

```bash
export AKASH_IMAGE="<registry>/akash-optimizer:prod"
export VAULT_ADDR="$VAULT_ADDR"
export VAULT_ROLE_ID="$AKASH_ROLE_ID"
export VAULT_SECRET_ID="$AKASH_SECRET_ID"
export VAULT_KV_MOUNT="kv"
export VAULT_SECRET_PATH="runtime/akash/prod"
export REQUIRED_SECRET_KEYS="AGENTSWARM_MASTER_KEY,SOLANA_RPC_URL,RUNPOD_API_KEY,VULTR_API_KEY,DIGITALOCEAN_TOKEN"
export AKASH_FROM="<akash-wallet-key-name>"

chmod +x deploy/akash/deploy.sh
./deploy/akash/deploy.sh
```

## 7) Production guardrails

- Use short TTLs and low `secret_id_num_uses` for AppRoles.
- Rotate Secret IDs regularly (`vault write -f .../secret-id`).
- Scope policies by environment path (for example `prod`, `staging`).
- Enable Vault audit logs in production.
- Never print secrets in CI logs (`set +x` around secret commands).
- Revoke tokens after use where possible:

```bash
vault token revoke -self
```

# HashiCorp Vault Integration Runbook

This runbook bootstraps Vault for this repository, stores cloud/RPC secrets, configures Terraform to read secrets from Vault, and deploys Akash with runtime-only secret injection.

## 0) Prerequisites

- Vault CLI authenticated to an admin token for bootstrap only.
- Terraform `>=1.6`.
- Docker (for Akash image build).
- Akash CLI (`provider-services`).
- `jq` installed locally for command snippets.

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="<bootstrap-admin-token>"
vault status
```

## 1) Bootstrap Vault mount, policies, and AppRoles (Terraform)

From repository root:

```bash
terraform -chdir=infra/terraform/vault-bootstrap init
terraform -chdir=infra/terraform/vault-bootstrap plan \
  -var "vault_addr=${VAULT_ADDR}" \
  -var "vault_token=${VAULT_TOKEN}"
terraform -chdir=infra/terraform/vault-bootstrap apply -auto-approve \
  -var "vault_addr=${VAULT_ADDR}" \
  -var "vault_token=${VAULT_TOKEN}"
```

This creates:

- KV v2 mount at `kv/`
- Policy `terraform-read-cloud-secrets`
- Policy `akash-runtime-read-secrets`
- AppRole `terraform-reader`
- AppRole `akash-runtime`

## 2) Write required Vault secrets

All Terraform provider credentials are loaded from Vault only:

```bash
vault kv put kv/platform/azure \
  tenant_id="<azure-tenant-id>" \
  subscription_id="<azure-subscription-id>" \
  client_id="<azure-client-id>" \
  client_secret="<azure-client-secret>"

vault kv put kv/platform/runpod \
  api_key="<runpod-api-key>"

vault kv put kv/platform/vultr \
  api_key="<vultr-api-key>"

vault kv put kv/platform/digitalocean \
  token="<digitalocean-token>"

vault kv put kv/platform/rpc \
  primary_url="https://rpc-primary.example.com" \
  failover_url_1="https://rpc-failover-1.example.com" \
  failover_url_2="https://rpc-failover-2.example.com"
```

Akash runtime secrets (keys **must** be uppercase `A-Z0-9_` to be exported by entrypoint):

```bash
vault kv put kv/platform/runtime/akash \
  AKASH_WALLET_ADDRESS="<wallet-address>" \
  AKASH_WALLET_MNEMONIC="<wallet-mnemonic>" \
  RUNPOD_API_KEY="<runpod-api-key>" \
  VULTR_API_KEY="<vultr-api-key>" \
  DIGITALOCEAN_TOKEN="<digitalocean-token>"
```

## 3) Run Terraform with Vault-backed credentials

Issue short-lived Terraform AppRole credentials and log in:

```bash
export TF_ROLE_ID="$(vault read -field=role_id auth/approle/role/terraform-reader/role-id)"
export TF_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/terraform-reader/secret-id)"
export TF_VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="${TF_ROLE_ID}" secret_id="${TF_SECRET_ID}")"
```

Run Terraform provider wiring:

```bash
terraform -chdir=infra/terraform/platform init
terraform -chdir=infra/terraform/platform plan \
  -var "vault_addr=${VAULT_ADDR}" \
  -var "vault_token=${TF_VAULT_TOKEN}"
terraform -chdir=infra/terraform/platform apply -auto-approve \
  -var "vault_addr=${VAULT_ADDR}" \
  -var "vault_token=${TF_VAULT_TOKEN}"
```

## 4) Build and push Akash runtime image

```bash
docker build -f deploy/akash/Dockerfile -t ghcr.io/your-org/yieldswarm-akash-optimizer:latest .
docker push ghcr.io/your-org/yieldswarm-akash-optimizer:latest
```

## 5) Deploy to Akash with runtime secret injection (no hardcoded secrets)

Generate one-time `secret_id` and role ID for `akash-runtime`:

```bash
export AKASH_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
export AKASH_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)"
```

Create an ephemeral Akash env file (never commit this file):

```bash
cat > deploy/akash/akash.env <<EOF
AKASH_IMAGE=ghcr.io/your-org/yieldswarm-akash-optimizer:latest
VAULT_ADDR=${VAULT_ADDR}
VAULT_NAMESPACE=
VAULT_AUTH_PATH=approle
VAULT_KV_MOUNT=kv
VAULT_AKASH_SECRET_PATH=platform/runtime/akash
VAULT_RPC_SECRET_PATH=platform/rpc
VAULT_ROLE_ID=${AKASH_ROLE_ID}
VAULT_SECRET_ID=${AKASH_SECRET_ID}
EOF
chmod 0600 deploy/akash/akash.env
```

Deploy:

```bash
provider-services tx deployment create deploy/akash/deployment.yaml \
  --from "<akash-key-name>" \
  --node "https://rpc.akashnet.net:443" \
  --chain-id "akashnet-2" \
  --gas auto \
  --gas-adjustment 1.3 \
  --env-file deploy/akash/akash.env
```

Destroy local env file immediately after deploy:

```bash
shred -u deploy/akash/akash.env || rm -f deploy/akash/akash.env
unset AKASH_SECRET_ID AKASH_ROLE_ID TF_SECRET_ID TF_ROLE_ID TF_VAULT_TOKEN VAULT_TOKEN
```

## 6) Operational hardening checklist

- Rotate all AppRole `secret_id` values on every pipeline/deploy run.
- Restrict `akash_token_bound_cidrs` in `infra/terraform/vault-bootstrap` for production networks.
- Use Vault audit devices and central log shipping.
- Never store Terraform state with secrets in an unencrypted backend.
- Restrict who can generate `secret_id` for `terraform-reader` and `akash-runtime`.

# HashiCorp Vault Secrets Setup

This repository stores no production secrets. Vault is the source of truth for cloud provider credentials and RPC configuration, and Akash containers fetch those secrets at startup with short-lived AppRole credentials.

## Secret layout

KV v2 mount:

```text
yieldswarm/
  cloud/azure
  cloud/runpod
  cloud/vultr
  cloud/digitalocean
  rpc
```

Required fields:

| Vault path | Fields |
| --- | --- |
| `yieldswarm/cloud/azure` | `subscription_id`, `tenant_id`, `client_id`, `client_secret` |
| `yieldswarm/cloud/runpod` | `api_key` |
| `yieldswarm/cloud/vultr` | `api_key` |
| `yieldswarm/cloud/digitalocean` | `token` |
| `yieldswarm/rpc` | `solana_rpc_url`, `failover_rpc_list_json` |

Optional RPC fields exported by the Akash entrypoint when present:

```text
helius_api_key
ethereum_rpc_url
base_rpc_url
polygon_rpc_url
```

## 1. Configure Vault engines, policies, and AppRole

Run these commands from a trusted operator workstation with an already-initialized and unsealed Vault cluster.

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="replace-with-a-root-or-admin-token"

cd infra/vault
terraform init -upgrade
terraform apply \
  -var "vault_addr=${VAULT_ADDR}" \
  -var "kv_mount_path=yieldswarm" \
  -var "approle_auth_path=approle"
```

The Vault Terraform stack creates:

- `yieldswarm` KV v2 secrets engine
- `yieldswarm-terraform-read` read-only policy for Terraform
- `yieldswarm-akash-runtime` read-only policy for Akash runtime workloads
- `yieldswarm-secret-operator` write/rotate policy for secret operators
- `yieldswarm-akash-runtime` AppRole with one-use, short-lived secret IDs

## 2. Write production secrets into Vault

Do not write secrets with Terraform resources; that would place the secret material in Terraform state. Write and rotate secret values with the Vault CLI or an approved secret ingestion pipeline.

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="replace-with-a-token-that-has-yieldswarm-secret-operator"

read -r -p "Azure subscription ID: " AZURE_SUBSCRIPTION_ID
read -r -p "Azure tenant ID: " AZURE_TENANT_ID
read -r -p "Azure client ID: " AZURE_CLIENT_ID
read -r -s -p "Azure client secret: " AZURE_CLIENT_SECRET && printf '\n'
vault kv put yieldswarm/cloud/azure \
  subscription_id="${AZURE_SUBSCRIPTION_ID}" \
  tenant_id="${AZURE_TENANT_ID}" \
  client_id="${AZURE_CLIENT_ID}" \
  client_secret="${AZURE_CLIENT_SECRET}"

read -r -s -p "RunPod API key: " RUNPOD_API_KEY && printf '\n'
vault kv put yieldswarm/cloud/runpod \
  api_key="${RUNPOD_API_KEY}"

read -r -s -p "Vultr API key: " VULTR_API_KEY && printf '\n'
vault kv put yieldswarm/cloud/vultr \
  api_key="${VULTR_API_KEY}"

read -r -s -p "DigitalOcean token: " DIGITALOCEAN_TOKEN && printf '\n'
vault kv put yieldswarm/cloud/digitalocean \
  token="${DIGITALOCEAN_TOKEN}"

read -r -p "Solana RPC URL: " SOLANA_RPC_URL
read -r -p "Failover RPC list JSON: " FAILOVER_RPC_LIST_JSON
read -r -s -p "Helius API key: " HELIUS_API_KEY && printf '\n'
read -r -p "Ethereum RPC URL: " ETHEREUM_RPC_URL
read -r -p "Base RPC URL: " BASE_RPC_URL
read -r -p "Polygon RPC URL: " POLYGON_RPC_URL
vault kv put yieldswarm/rpc \
  solana_rpc_url="${SOLANA_RPC_URL}" \
  failover_rpc_list_json="${FAILOVER_RPC_LIST_JSON}" \
  helius_api_key="${HELIUS_API_KEY}" \
  ethereum_rpc_url="${ETHEREUM_RPC_URL}" \
  base_rpc_url="${BASE_RPC_URL}" \
  polygon_rpc_url="${POLYGON_RPC_URL}"

unset AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET
unset RUNPOD_API_KEY VULTR_API_KEY DIGITALOCEAN_TOKEN
unset SOLANA_RPC_URL FAILOVER_RPC_LIST_JSON HELIUS_API_KEY ETHEREUM_RPC_URL BASE_RPC_URL POLYGON_RPC_URL
```

Verify secret versions without printing values:

```bash
vault kv metadata get yieldswarm/cloud/azure
vault kv metadata get yieldswarm/cloud/runpod
vault kv metadata get yieldswarm/cloud/vultr
vault kv metadata get yieldswarm/cloud/digitalocean
vault kv metadata get yieldswarm/rpc
```

## 3. Run Terraform with Vault-backed providers

Terraform reads Azure, RunPod, Vultr, DigitalOcean, and RPC configuration from Vault in `infra/terraform`.

Production requirement: use an encrypted, access-controlled remote backend before running `plan` or `apply`. Vault data source values can be persisted in Terraform state even when output is marked sensitive. Never commit local state files or plan files.

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="$(vault token create \
  -policy=yieldswarm-terraform-read \
  -period=1h \
  -renewable=true \
  -field=token)"

cd infra/terraform
terraform init -upgrade
terraform plan \
  -var "vault_addr=${VAULT_ADDR}" \
  -var "vault_kv_mount=yieldswarm"
```

When applying infrastructure from this stack:

```bash
terraform apply \
  -var "vault_addr=${VAULT_ADDR}" \
  -var "vault_kv_mount=yieldswarm"
```

## 4. Build the Akash runtime image

The image includes `deploy/akash/entrypoint.sh`. The entrypoint authenticates to Vault, exports secrets into the application process environment, unsets Vault bootstrap credentials, and then starts the command.

```bash
export IMAGE_REGISTRY="ghcr.io/your-org"
export IMAGE_TAG="$(git rev-parse --short HEAD)"
export AKASH_IMAGE="${IMAGE_REGISTRY}/yieldswarm:${IMAGE_TAG}"

docker build \
  -f deploy/akash/Dockerfile \
  -t "${AKASH_IMAGE}" \
  .

docker push "${AKASH_IMAGE}"
```

## 5. Render and deploy Akash SDL with a wrapped secret ID

The deployment template expects a wrapped AppRole secret ID. The wrapped token is single-use and short-lived; render and submit the deployment immediately after creating it.

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE=""
export VAULT_AUTH_PATH="approle"
export VAULT_KV_MOUNT="yieldswarm"
export VAULT_ROLE_ID="$(vault read \
  -field=role_id \
  auth/approle/role/yieldswarm-akash-runtime/role-id)"
export VAULT_WRAPPED_SECRET_ID="$(vault write \
  -f \
  -wrap-ttl=10m \
  -field=wrapping_token \
  auth/approle/role/yieldswarm-akash-runtime/secret-id)"

export AKASH_IMAGE="ghcr.io/your-org/yieldswarm:replace-with-image-tag"
export AKASH_KEY_NAME="replace-with-akash-key-name"
export AKASH_CHAIN_ID="akashnet-2"
export AKASH_NODE="https://rpc.akashnet.net:443"
export AKASH_FEES="5000uakt"

mkdir -p .generated/akash
envsubst < deploy/akash/deploy.yaml.tpl > .generated/akash/deploy.yaml

akash tx deployment create .generated/akash/deploy.yaml \
  --from "${AKASH_KEY_NAME}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --node "${AKASH_NODE}" \
  --fees "${AKASH_FEES}" \
  -y

shred -u .generated/akash/deploy.yaml 2>/dev/null || rm -f .generated/akash/deploy.yaml
unset VAULT_WRAPPED_SECRET_ID
```

If the deploy command is not submitted within the wrap TTL, generate a new `VAULT_WRAPPED_SECRET_ID` and render the SDL again.

## 6. Rotation commands

Rotate any provider secret by writing a new version to the same path:

```bash
read -r -s -p "New RunPod API key: " RUNPOD_API_KEY && printf '\n'
vault kv put yieldswarm/cloud/runpod api_key="${RUNPOD_API_KEY}"
unset RUNPOD_API_KEY
```

Then restart or redeploy workloads so the entrypoint fetches the new version:

```bash
export VAULT_WRAPPED_SECRET_ID="$(vault write \
  -f \
  -wrap-ttl=10m \
  -field=wrapping_token \
  auth/approle/role/yieldswarm-akash-runtime/secret-id)"
mkdir -p .generated/akash
envsubst < deploy/akash/deploy.yaml.tpl > .generated/akash/deploy.yaml
akash tx deployment update .generated/akash/deploy.yaml \
  --from "${AKASH_KEY_NAME}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --node "${AKASH_NODE}" \
  --fees "${AKASH_FEES}" \
  -y
shred -u .generated/akash/deploy.yaml 2>/dev/null || rm -f .generated/akash/deploy.yaml
unset VAULT_WRAPPED_SECRET_ID
```

## Operational rules

- Never commit `.env`, Terraform state, Terraform plan files, or rendered Akash manifests.
- Never place raw provider keys in Akash SDL, Terraform variables, CI logs, or shell history.
- Keep AppRole secret IDs one-use and wrapped with a short TTL.
- Prefer dedicated Vault tokens per automation system and attach only the policy it needs.
- Restrict Terraform state access to the same trust boundary as the secrets it contains.

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

vault kv put yieldswarm/cloud/azure \
  subscription_id="00000000-0000-0000-0000-000000000000" \
  tenant_id="00000000-0000-0000-0000-000000000000" \
  client_id="00000000-0000-0000-0000-000000000000" \
  client_secret="replace-with-azure-client-secret"

vault kv put yieldswarm/cloud/runpod \
  api_key="replace-with-runpod-api-key"

vault kv put yieldswarm/cloud/vultr \
  api_key="replace-with-vultr-api-key"

vault kv put yieldswarm/cloud/digitalocean \
  token="replace-with-digitalocean-token"

vault kv put yieldswarm/rpc \
  solana_rpc_url="https://replace-with-solana-rpc.example.com" \
  failover_rpc_list_json='["https://replace-with-rpc-1.example.com","https://replace-with-rpc-2.example.com"]' \
  helius_api_key="replace-with-helius-api-key" \
  ethereum_rpc_url="https://replace-with-ethereum-rpc.example.com" \
  base_rpc_url="https://replace-with-base-rpc.example.com" \
  polygon_rpc_url="https://replace-with-polygon-rpc.example.com"
```

Verify only metadata and expected field names, not values:

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
vault kv put yieldswarm/cloud/runpod api_key="replace-with-new-runpod-api-key"
```

Then restart or redeploy workloads so the entrypoint fetches the new version:

```bash
export VAULT_WRAPPED_SECRET_ID="$(vault write \
  -f \
  -wrap-ttl=10m \
  -field=wrapping_token \
  auth/approle/role/yieldswarm-akash-runtime/secret-id)"
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

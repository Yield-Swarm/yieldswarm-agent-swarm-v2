# Secrets and Vault Setup

This repository is wired for a Vault-first workflow:

- Vault owns all production secrets.
- Terraform reads Azure, RunPod, Vultr, DigitalOcean, and RPC credentials from Vault KV v2.
- OpenClaw on Akash authenticates to Vault at container startup and injects secrets into the process environment at runtime.
- No real secret values belong in git, in the Docker image, or in the committed Akash SDL template.

## 1. Prerequisites

Install the required operator tooling on Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y curl jq gettext-base ca-certificates gnupg software-properties-common
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
terraform version
vault version
provider-services version
docker version
```

Required environment for the rest of this guide:

```bash
export REPO_ROOT="/workspace"
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="hvs.REPLACE_ME"
export VAULT_NAMESPACE=""
```

If you use a private Vault CA, keep the PEM file on the operator machine:

```bash
export VAULT_CACERT="/path/to/vault-ca.pem"
```

## 2. Bootstrap Vault mounts, policies, and AppRoles

The bootstrap Terraform creates:

- `kvv2/` KV v2 for provider and application secrets
- `transit/` for application-side cryptography
- `auth/approle/` for machine authentication
- `yieldswarm-terraform` policy and AppRole
- `openclaw-runtime` policy and AppRole

Run:

```bash
cd "${REPO_ROOT}/infra/vault/bootstrap"
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

If you know the stable CIDR(s) that Akash egresses from, bind the OpenClaw SecretID and token to them:

```bash
cd "${REPO_ROOT}/infra/vault/bootstrap"
terraform apply \
  -var='openclaw_secret_id_bound_cidrs=["198.51.100.10/32"]' \
  -var='openclaw_token_bound_cidrs=["198.51.100.10/32"]'
```

Capture the generated RoleIDs:

```bash
export TERRAFORM_VAULT_ROLE_ID="$(terraform output -raw terraform_role_id)"
export OPENCLAW_VAULT_ROLE_ID="$(terraform output -raw openclaw_role_id)"
```

## 3. Write provider and RPC secrets into Vault

The Terraform consumer expects the following Vault KV v2 paths.

### Azure provider secret

```bash
vault kv put kvv2/providers/azure \
  client_id="00000000-0000-0000-0000-000000000000" \
  client_secret="REPLACE_ME" \
  subscription_id="00000000-0000-0000-0000-000000000000" \
  tenant_id="00000000-0000-0000-0000-000000000000"
```

### RunPod provider secret

```bash
vault kv put kvv2/providers/runpod \
  api_key="REPLACE_ME"
```

### Vultr provider secret

```bash
vault kv put kvv2/providers/vultr \
  api_key="REPLACE_ME"
```

### DigitalOcean provider secret

```bash
vault kv put kvv2/providers/digitalocean \
  token="REPLACE_ME"
```

### RPC secret

```bash
vault kv put kvv2/network/rpc \
  primary_url="https://rpc.example.com" \
  websocket_url="wss://rpc.example.com/ws" \
  failover_urls_json='["https://rpc-1.example.com","https://rpc-2.example.com"]' \
  auth_header="Bearer REPLACE_ME"
```

## 4. Write the OpenClaw runtime secret bundle

Every top-level key stored at `kvv2/apps/openclaw/runtime` is exported by the Akash entrypoint into the OpenClaw process environment at startup.

Example bundle:

```bash
vault kv put kvv2/apps/openclaw/runtime \
  OPENAI_API_KEY="REPLACE_ME" \
  ANTHROPIC_API_KEY="REPLACE_ME" \
  GROK_API_KEY="REPLACE_ME" \
  RUNPOD_API_KEY="REPLACE_ME" \
  DIGITALOCEAN_TOKEN="REPLACE_ME" \
  VULTR_API_KEY="REPLACE_ME" \
  AZURE_CLIENT_ID="00000000-0000-0000-0000-000000000000" \
  AZURE_CLIENT_SECRET="REPLACE_ME" \
  AZURE_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" \
  AZURE_TENANT_ID="00000000-0000-0000-0000-000000000000" \
  SOLANA_RPC_URL="https://rpc.example.com" \
  FAILOVER_RPC_LIST='["https://rpc-1.example.com","https://rpc-2.example.com"]'
```

## 5. Run Terraform with Vault-backed provider credentials

Generate a short-lived SecretID for Terraform and keep it only in the current shell:

```bash
export TF_VAR_vault_addr="${VAULT_ADDR}"
export TF_VAR_vault_namespace="${VAULT_NAMESPACE}"
export TF_VAR_vault_role_id="${TERRAFORM_VAULT_ROLE_ID}"
export TF_VAR_vault_secret_id="$(vault write -field=secret_id -force auth/approle/role/yieldswarm-terraform/secret-id)"
```

Initialize and verify the consumer stack:

```bash
cd "${REPO_ROOT}/infra/terraform"
terraform init
terraform validate
terraform plan
```

When you are done, clear the SecretID from the shell:

```bash
unset TF_VAR_vault_secret_id
```

## 6. Build and publish the OpenClaw image

The image contains no embedded credentials. Secrets are fetched only at runtime.

```bash
cd "${REPO_ROOT}"
export OPENCLAW_IMAGE="ghcr.io/YOUR_ORG/yieldswarm-openclaw:$(git rev-parse --short HEAD)"
docker build -f docker/openclaw/Dockerfile -t "${OPENCLAW_IMAGE}" .
docker push "${OPENCLAW_IMAGE}"
```

## 7. Render the Akash SDL with a wrapped SecretID

Never commit a rendered SDL that contains deployment-time values. The committed file is the template:

- `deploy/akash/openclaw.sdl.tpl` (safe to commit)
- `deploy/akash/openclaw.local.sdl` (generated locally, ignored by git)

Set the deployment values:

```bash
cd "${REPO_ROOT}"
export OPENCLAW_ENVIRONMENT="prod"
export VAULT_AUTH_PATH="approle"
export VAULT_KV_MOUNT="kvv2"
export VAULT_SECRET_PATH="apps/openclaw/runtime"
export VAULT_ROLE_ID="${OPENCLAW_VAULT_ROLE_ID}"
export VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=5m -field=wrapping_token -force auth/approle/role/openclaw-runtime/secret-id)"
export VAULT_CACERT_B64=""
```

If Vault uses a private CA, encode it into a single line before rendering:

```bash
export VAULT_CACERT_B64="$(base64 -w 0 "${VAULT_CACERT}")"
```

Render and validate the SDL:

```bash
envsubst < deploy/akash/openclaw.sdl.tpl > deploy/akash/openclaw.local.sdl
provider-services deployment validate deploy/akash/openclaw.local.sdl
```

## 8. Deploy to Akash

Configure the Akash client environment first:

```bash
export AKASH_KEY_NAME="REPLACE_ME"
export AKASH_NODE="https://rpc.akashnet.net:443"
export AKASH_CHAIN_ID="akashnet-2"
export AKASH_GAS="auto"
export AKASH_GAS_ADJUSTMENT="1.4"
export AKASH_GAS_PRICES="0.025uakt"
```

Create the deployment:

```bash
DEPLOY_RESULT="$(provider-services tx deployment create deploy/akash/openclaw.local.sdl --from "${AKASH_KEY_NAME}" -y --output json)"
export AKASH_DSEQ="$(printf '%s' "${DEPLOY_RESULT}" | jq -r '.logs[0].events[] | select(.type=="akash.v1.EventDeploymentCreated") | .attributes[] | select(.key=="dseq") | .value')"
echo "${AKASH_DSEQ}"
```

Pick a provider from the live bids, then create the lease and send the manifest:

```bash
provider-services query market bid list --dseq "${AKASH_DSEQ}" --state=open
export AKASH_PROVIDER="REPLACE_WITH_PROVIDER_ADDRESS"
provider-services tx market lease create --dseq "${AKASH_DSEQ}" --provider "${AKASH_PROVIDER}" --from "${AKASH_KEY_NAME}" -y
provider-services send-manifest deploy/akash/openclaw.local.sdl --dseq "${AKASH_DSEQ}" --provider "${AKASH_PROVIDER}" --from "${AKASH_KEY_NAME}"
```

Destroy the rendered SDL after the deployment is accepted:

```bash
shred -u deploy/akash/openclaw.local.sdl 2>/dev/null || rm -f deploy/akash/openclaw.local.sdl
unset VAULT_WRAPPED_SECRET_ID
```

## 9. Rotate secrets safely

Rotate secrets in Vault, mint a fresh wrapped SecretID, re-render the local SDL, and update the deployment.

Example:

```bash
vault kv patch kvv2/apps/openclaw/runtime OPENAI_API_KEY="REPLACE_WITH_NEW_VALUE"
export VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=5m -field=wrapping_token -force auth/approle/role/openclaw-runtime/secret-id)"
envsubst < deploy/akash/openclaw.sdl.tpl > deploy/akash/openclaw.local.sdl
provider-services tx deployment update deploy/akash/openclaw.local.sdl --dseq "${AKASH_DSEQ}" --from "${AKASH_KEY_NAME}" -y
provider-services send-manifest deploy/akash/openclaw.local.sdl --dseq "${AKASH_DSEQ}" --provider "${AKASH_PROVIDER}" --from "${AKASH_KEY_NAME}"
shred -u deploy/akash/openclaw.local.sdl 2>/dev/null || rm -f deploy/akash/openclaw.local.sdl
```

## 10. Expected Vault paths

| Path | Purpose |
| --- | --- |
| `kvv2/providers/azure` | AzureRM provider credentials |
| `kvv2/providers/runpod` | RunPod provider API key |
| `kvv2/providers/vultr` | Vultr provider API key |
| `kvv2/providers/digitalocean` | DigitalOcean provider token |
| `kvv2/network/rpc` | Primary and failover RPC endpoints |
| `kvv2/apps/openclaw/runtime` | Runtime secret bundle exported into the container |
| `transit/encrypt/openclaw-runtime` | Transit encryption endpoint for application use |

## 11. Security rules

- Never commit `*.tfvars`, `.env`, or `deploy/akash/openclaw.local.sdl`.
- Never place real secret values in `deploy/akash/openclaw.sdl.tpl`.
- Prefer wrapped SecretIDs for workloads; they are single-use and short-lived.
- Keep Vault policies narrow. Add new paths explicitly instead of widening wildcards.
- Rotate AppRole SecretIDs and provider credentials on a regular schedule.

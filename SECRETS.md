# Secrets and Vault Setup

This repository now treats HashiCorp Vault as the production source of truth for:

- Terraform cloud provider credentials
- RPC credentials and failover endpoints
- Akash runtime environment variables

The repository does **not** store real secrets. Terraform reads provider credentials from Vault at runtime using AppRole authentication, and the Akash workload fetches its runtime environment from Vault inside the container before the workload starts.

## What this setup creates

- KV v2 mount: `kv`
- Transit mount: `transit`
- AppRole auth mount: `approle`
- Vault policy: `terraform-platform`
- Vault policy: `akash-runtime`
- AppRole: `terraform-platform`
- AppRole: `akash-runtime`

## Production requirements

- Vault must be reachable over TLS.
- Do **not** set `vault_skip_tls_verify = true` in production.
- Use a remote Terraform backend with encryption and locking.
- Do **not** commit `*.tfvars`, Terraform state, rendered Akash manifests, or wrapped tokens.
- Use short-lived AppRole SecretIDs. The Akash deployment flow below uses a **response-wrapped** SecretID token so the raw SecretID never needs to be inserted into the deployment manifest.

## 1. Bootstrap Vault mounts, policies, and AppRoles

These commands create the Vault structure. They do **not** write secret values into Terraform state.

```bash
cd /workspace/infra/terraform/vault-bootstrap

export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE="admin"
export VAULT_TOKEN="REPLACE_WITH_OPERATOR_TOKEN"
export TF_VAR_vault_address="${VAULT_ADDR}"
export TF_VAR_vault_namespace="${VAULT_NAMESPACE}"
export TF_VAR_vault_token="${VAULT_TOKEN}"

terraform init
terraform apply
```

If you are not using Vault Enterprise namespaces, omit `VAULT_NAMESPACE` and do not export `TF_VAR_vault_namespace`.

## 2. Write the provider and runtime secrets into Vault

Write each provider secret into its own KV v2 path. These commands assume the default mount path `kv`.

### Azure service principal

```bash
vault kv put kv/platform/providers/azure \
  client_id="REPLACE_WITH_AZURE_CLIENT_ID" \
  client_secret="REPLACE_WITH_AZURE_CLIENT_SECRET" \
  tenant_id="REPLACE_WITH_AZURE_TENANT_ID" \
  subscription_id="REPLACE_WITH_AZURE_SUBSCRIPTION_ID"
```

### RunPod

```bash
vault kv put kv/platform/providers/runpod \
  api_key="REPLACE_WITH_RUNPOD_API_KEY"
```

### Vultr

```bash
vault kv put kv/platform/providers/vultr \
  api_key="REPLACE_WITH_VULTR_API_KEY"
```

### DigitalOcean

```bash
vault kv put kv/platform/providers/digitalocean \
  token="REPLACE_WITH_DIGITALOCEAN_TOKEN"
```

### RPC endpoints

Store failover URLs as JSON so Terraform can decode them safely.

```bash
vault kv put kv/platform/rpc/mainnet \
  primary_url="https://rpc-1.example.com" \
  websocket_url="wss://rpc-1.example.com/ws" \
  failover_urls_json='["https://rpc-2.example.com","https://rpc-3.example.com"]' \
  auth_header="Bearer REPLACE_WITH_RPC_BEARER_TOKEN"
```

### Akash runtime environment bundle

The Akash entrypoint expects this secret to contain environment-variable keys. Every key becomes an exported environment variable in the container at startup.

```bash
vault kv put kv/runtime/akash \
  AGENTSWARM_MASTER_KEY="REPLACE_WITH_MASTER_KEY" \
  OPENAI_API_KEY="REPLACE_WITH_OPENAI_KEY" \
  ANTHROPIC_API_KEY="REPLACE_WITH_ANTHROPIC_KEY" \
  GROK_API_KEY="REPLACE_WITH_GROK_KEY" \
  GEMINI_API_KEY="REPLACE_WITH_GEMINI_KEY" \
  SOLANA_RPC_URL="https://rpc-1.example.com" \
  FAILOVER_RPC_LIST='["https://rpc-2.example.com","https://rpc-3.example.com"]' \
  HELIUS_API_KEY="REPLACE_WITH_HELIUS_KEY" \
  LOG_LEVEL="INFO"
```

Add every other runtime secret your workload requires to the same `vault kv put` command or by patching the path later with `vault kv patch kv/runtime/akash ...`.

## 3. Run Terraform using Vault-backed provider credentials

Generate a short-lived SecretID for the Terraform AppRole and export it only for the duration of the run.

```bash
export TF_VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/terraform-platform/role-id)"
export TF_VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/terraform-platform/secret-id)"
```

Run Terraform from the provider-consumer stack:

```bash
cd /workspace/infra/terraform/platform

export TF_VAR_vault_address="${VAULT_ADDR}"
export TF_VAR_vault_namespace="${VAULT_NAMESPACE}"
export TF_VAR_vault_role_id="${TF_VAULT_ROLE_ID}"
export TF_VAR_vault_secret_id="${TF_VAULT_SECRET_ID}"

terraform init
terraform plan
terraform apply
```

### Secret contract expected by Terraform

Terraform reads these Vault paths at runtime:

- `kv/platform/providers/azure`
  - `client_id`
  - `client_secret`
  - `tenant_id`
  - `subscription_id`
- `kv/platform/providers/runpod`
  - `api_key`
- `kv/platform/providers/vultr`
  - `api_key`
- `kv/platform/providers/digitalocean`
  - `token`
- `kv/platform/rpc/mainnet`
  - `primary_url`
  - `websocket_url`
  - `failover_urls_json`
  - optional: `auth_header`

## 4. Build and publish the Akash image

The image bakes in the Vault-aware entrypoint, but **not** any secrets.

```bash
cd /workspace

export IMAGE="ghcr.io/REPLACE_WITH_ORG/yieldswarm-akash:$(git rev-parse --short HEAD)"

docker build -f deploy/akash/Dockerfile -t "${IMAGE}" .
docker push "${IMAGE}"
```

## 5. Render the Akash deployment manifest with a wrapped SecretID token

Create a role ID and a **response-wrapped** SecretID token for the Akash runtime AppRole:

```bash
export VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"
export VAULT_WRAPPED_SECRET_ID_TOKEN="$(vault write -wrap-ttl=10m -f -field=wrapping_token auth/approle/role/akash-runtime/secret-id)"
```

Set the deployment parameters:

```bash
export IMAGE="${IMAGE}"
export VAULT_ADDR="${VAULT_ADDR}"
export VAULT_NAMESPACE="${VAULT_NAMESPACE}"
export VAULT_AUTH_PATH="approle"
export VAULT_KV_MOUNT="kv"
export VAULT_SECRET_PATH="runtime/akash"
export VAULT_CACERT_PATH="/etc/ssl/certs/ca-certificates.crt"
export VAULT_SKIP_VERIFY="false"
export VAULT_MAX_ATTEMPTS="5"
export VAULT_RETRY_BACKOFF_SECONDS="2"
export AKASH_CPU_UNITS="1.0"
export AKASH_MEMORY_SIZE="2Gi"
export AKASH_STORAGE_SIZE="10Gi"
export AKASH_PRICE_AMOUNT="1000"
export AKASH_REPLICAS="1"
```

Render the final SDL from the template:

```bash
python3 - <<'PY'
from pathlib import Path
from string import Template
import os

template = Template(Path("deploy/akash/deployment.sdl.tpl").read_text())
Path("deploy/akash/deployment.sdl").write_text(template.substitute(os.environ))
PY
```

Deploy it with the Akash CLI:

```bash
provider-services tx deployment create deploy/akash/deployment.sdl \
  --from "${AKASH_WALLET}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --gas auto \
  --gas-adjustment 1.2 \
  --fees 5000uakt \
  -y
```

## 6. Rotation workflow

### Rotate a cloud provider credential

Overwrite the secret in Vault and rerun Terraform:

```bash
vault kv put kv/platform/providers/runpod \
  api_key="REPLACE_WITH_NEW_RUNPOD_API_KEY"
```

Then generate a fresh Terraform SecretID and rerun:

```bash
export TF_VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/terraform-platform/secret-id)"
cd /workspace/infra/terraform/platform
terraform plan
terraform apply
```

### Rotate Akash runtime secrets

Patch the runtime bundle and redeploy with a fresh wrapped SecretID token:

```bash
vault kv patch kv/runtime/akash \
  OPENAI_API_KEY="REPLACE_WITH_NEW_OPENAI_KEY"

export VAULT_WRAPPED_SECRET_ID_TOKEN="$(vault write -wrap-ttl=10m -f -field=wrapping_token auth/approle/role/akash-runtime/secret-id)"
python3 - <<'PY'
from pathlib import Path
from string import Template
import os

template = Template(Path("deploy/akash/deployment.sdl.tpl").read_text())
Path("deploy/akash/deployment.sdl").write_text(template.substitute(os.environ))
PY
provider-services tx deployment update deploy/akash/deployment.sdl \
  --from "${AKASH_WALLET}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --gas auto \
  --gas-adjustment 1.2 \
  --fees 5000uakt \
  -y
```

## 7. Operational notes

- The Akash entrypoint accepts either `VAULT_SECRET_ID` or `VAULT_WRAPPED_SECRET_ID_TOKEN`; prefer the wrapped token in production.
- The Akash entrypoint revokes its Vault token on exit.
- Invalid Vault key names are rejected before they can be sourced into the container shell.
- Keep Vault policies least-privilege. Do not reuse the Terraform AppRole for runtime workloads.
- Keep Vault audit logging enabled on the cluster.

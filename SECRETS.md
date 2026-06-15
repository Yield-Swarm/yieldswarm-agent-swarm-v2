# SECRETS.md — YieldSwarm AgentSwarm OS
## HashiCorp Vault Integration Setup Guide

This document is the single source of truth for secrets management across the entire AgentSwarm OS stack. **No secret value is ever hardcoded, committed to VCS, or stored in plain text anywhere in this repository.**

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     HashiCorp Vault                             │
│                                                                 │
│  KV v2 Engine (secret/)                                         │
│  ├── agentswarm/core          ← master keys, encryption keys    │
│  ├── agentswarm/llm           ← OpenAI, Grok, Gemini, Anthropic │
│  ├── agentswarm/rpc           ← Solana RPC, Helius, Jupiter …   │
│  ├── agentswarm/cloud/        ← cloud provider credentials      │
│  │   ├── azure                                                  │
│  │   ├── runpod                                                 │
│  │   ├── vultr                                                  │
│  │   └── digitalocean                                           │
│  ├── agentswarm/depin         ← Helium, Grass, GPU cluster keys │
│  ├── agentswarm/integrations  ← Notion, GitHub, Telegram …      │
│  └── agentswarm/payments      ← UD Domains, Wise               │
│                                                                 │
│  AppRole Auth                                                   │
│  ├── terraform      → reads cloud/* and rpc at plan time        │
│  ├── akash-runtime  → reads core, llm, rpc, depin, integrations │
│  └── ci-deploy      → reads cloud/azure and integrations        │
└────────────────┬──────────────────────────────────────┬─────────┘
                 │                                      │
    ┌────────────▼────────────┐          ┌─────────────▼──────────┐
    │  Terraform              │          │  Akash Containers       │
    │  (vault provider)       │          │  (entrypoint.sh)        │
    │                         │          │                         │
    │  - Azure Container Apps │          │  1. AppRole login        │
    │  - RunPod GPU pods      │          │  2. kv_export() each    │
    │  - Vultr VPS nodes      │          │     secret path         │
    │  - DigitalOcean         │          │  3. exec python agent   │
    └─────────────────────────┘          └────────────────────────┘
```

---

## Prerequisites

| Tool | Minimum Version | Install |
|------|----------------|---------|
| HashiCorp Vault | 1.17+ | https://developer.hashicorp.com/vault/install |
| Terraform | 1.9+ | https://developer.hashicorp.com/terraform/install |
| Docker | 24+ | https://docs.docker.com/get-docker/ |
| Akash CLI | 0.36+ | https://docs.akash.network/getting-started/install |
| jq | 1.6+ | `apt install jq` / `brew install jq` |

---

## Step 1 — Deploy and Configure Vault

### Option A: Docker (fastest for getting started)

```bash
# Generate self-signed TLS cert (replace with a real cert in production)
mkdir -p /vault/tls /vault/data /vault/logs
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout /vault/tls/vault.key \
  -out /vault/tls/vault.crt \
  -subj "/CN=vault" \
  -addext "subjectAltName=IP:127.0.0.1,DNS:vault,DNS:vault.yourdomain.com"

# Start Vault
docker run -d \
  --name vault \
  --cap-add IPC_LOCK \
  -p 8200:8200 -p 8201:8201 \
  -v /vault:/vault \
  -v $(pwd)/vault/config/vault.hcl:/vault/config/vault.hcl:ro \
  hashicorp/vault:1.17 \
  vault server -config=/vault/config/vault.hcl
```

### Option B: Systemd on Linux

```bash
# Install Vault
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vault

# Copy config and start
sudo cp vault/config/vault.hcl /etc/vault.d/vault.hcl
sudo sed -i 's/VAULT_HOSTNAME/your-vault-hostname/g' /etc/vault.d/vault.hcl
sudo systemctl enable --now vault
```

---

## Step 2 — Initialize and Unseal Vault

```bash
export VAULT_ADDR=https://your-vault-hostname:8200
export VAULT_SKIP_VERIFY=true  # remove once you have a trusted cert

# Initialize (5-of-5 key shares, threshold = 3)
vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > /tmp/vault-init.json

# CRITICAL: Save all 5 unseal keys and the root token from vault-init.json
# to separate secure locations (password manager, HSM, printed copies in
# separate physical locations). Once you close this terminal, these are
# UNRECOVERABLE if you lose them.

cat /tmp/vault-init.json | jq '.unseal_keys_b64'
cat /tmp/vault-init.json | jq -r '.root_token'

# Unseal with 3 of the 5 keys
vault operator unseal $(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[0]')
vault operator unseal $(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[1]')
vault operator unseal $(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[2]')

# Authenticate with root token
export VAULT_TOKEN=$(cat /tmp/vault-init.json | jq -r '.root_token')

# Confirm Vault is unsealed and authenticated
vault status
vault token lookup
```

### Auto-Unseal (Recommended for Production)

Uncomment and configure the `seal "azurekeyvault"` block in `vault/config/vault.hcl` before running `vault operator init`. With auto-unseal, Vault unseals automatically on restart without human intervention.

```bash
# Create Azure Key Vault key (one-time setup before Vault init)
az keyvault create --name ys-vault-unseal --resource-group agentswarm-rg --location eastus
az keyvault key create --vault-name ys-vault-unseal --name vault-unseal-key --kty RSA --size 4096
```

---

## Step 3 — Run Bootstrap Script

The bootstrap script sets up all Vault policies, AppRole roles, and secret path scaffolding. It is safe to re-run.

```bash
export VAULT_ADDR=https://your-vault-hostname:8200
export VAULT_TOKEN=<root-or-admin-token>

bash vault/init/bootstrap.sh
```

Expected output ends with a printed table of AppRole `role_id` values. Copy the `akash-runtime` role_id — you will need it shortly.

---

## Step 4 — Seed Secrets

Run the interactive seeding script. It prompts for each secret without echoing to the terminal.

```bash
export VAULT_ADDR=https://your-vault-hostname:8200
export VAULT_TOKEN=<root-or-admin-token>

bash vault/init/seed-secrets.sh
```

Alternatively, seed secrets non-interactively using environment variables (useful in CI):

```bash
AGENTSWARM_MASTER_KEY="$(op read 'op://Vault/AgentSwarm/master_key')" \
OPENAI_API_KEY="$(op read 'op://Vault/OpenAI/credential')" \
  bash vault/init/seed-secrets.sh
```

Verify:

```bash
vault kv list secret/agentswarm/
vault kv get secret/agentswarm/core
vault kv get secret/agentswarm/llm
vault kv get secret/agentswarm/cloud/azure
```

---

## Step 5 — Configure Terraform

### 5.1 Get Terraform's AppRole credentials

```bash
# role_id is non-sensitive — commit to CI variables if needed
TERRAFORM_ROLE_ID=$(vault read -field=role_id auth/approle/role/terraform/role-id)
echo "TERRAFORM_ROLE_ID=${TERRAFORM_ROLE_ID}"

# secret_id is sensitive — generate fresh each time
TERRAFORM_WRAPPED=$(vault write -wrap-ttl=10m -field=wrapping_token \
  -f auth/approle/role/terraform/secret-id)

# Unwrap to get the actual secret_id (do this immediately — 10 min TTL)
TERRAFORM_SECRET_ID=$(vault unwrap -field=secret_id "${TERRAFORM_WRAPPED}")
```

### 5.2 Authenticate Terraform with Vault

```bash
# Exchange AppRole credentials for a Vault token
VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="${TERRAFORM_ROLE_ID}" \
  secret_id="${TERRAFORM_SECRET_ID}")

export VAULT_ADDR=https://your-vault-hostname:8200
export VAULT_TOKEN
```

### 5.3 Configure non-secret variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — fill in region, sizes, vault_addr, image tag
# Do NOT add secrets; they come from Vault automatically
```

### 5.4 Supply AppRole credentials for the agent containers

```bash
# These are passed to Terraform so it can inject them into Container Apps / cloud-init
export TF_VAR_vault_approle_role_id=$(vault read -field=role_id \
  auth/approle/role/akash-runtime/role-id)

# Generate a fresh wrapped secret_id — Terraform will store this in container env vars
export TF_VAR_vault_approle_secret_id=$(vault write -wrap-ttl=10m \
  -field=wrapping_token -f auth/approle/role/akash-runtime/secret-id)
```

### 5.5 Plan and apply

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform reads every cloud provider credential directly from Vault. No secret ever appears in `terraform.tfvars` or environment variables other than `VAULT_ADDR` and `VAULT_TOKEN`.

---

## Step 6 — Deploy to Akash Network

### 6.1 Build and push the container image

```bash
# Build
docker build -f akash/Dockerfile -t ghcr.io/yieldswarm/agentswarm-os:latest .

# Push (authenticate first)
echo "${GITHUB_TOKEN}" | docker login ghcr.io -u USERNAME --password-stdin
docker push ghcr.io/yieldswarm/agentswarm-os:latest
```

### 6.2 Get the AppRole credentials for Akash

```bash
AKASH_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
echo "VAULT_ROLE_ID=${AKASH_ROLE_ID}"   # Safe to embed in deploy.yaml
```

### 6.3 Generate a wrapped secret_id (single use, 10 min TTL)

This must be done **immediately before** each deployment. The secret_id is consumed on the container's first Vault login.

```bash
WRAPPED_SECRET=$(vault write -wrap-ttl=10m -field=wrapping_token \
  -f auth/approle/role/akash-runtime/secret-id)
echo "VAULT_SECRET_ID=${WRAPPED_SECRET}"
```

### 6.4 Deploy one shard

```bash
# Fill in the three placeholders in deploy.yaml, then:
akash tx deployment create akash/deploy.yaml \
  --from YOUR_KEYNAME \
  --node https://rpc.akash.forbole.com:443 \
  --chain-id akashnet-2 \
  --gas auto --gas-adjustment 1.4 --fees 5000uakt -y
```

### 6.5 Deploy all 120 shards at once

```bash
export VAULT_ADDR=https://your-vault-hostname:8200
export VAULT_TOKEN=<admin-token>
export VAULT_ROLE_ID="${AKASH_ROLE_ID}"
export AKASH_KEYNAME="your-wallet"
export AKASH_NODE="https://rpc.akash.forbole.com:443"
export AKASH_CHAIN_ID="akashnet-2"

bash akash/deploy-shards.sh
```

This script generates a fresh wrapped `secret_id` per shard so that each container has a unique, single-use credential.

### 6.6 Local testing with Docker Compose

```bash
# Starts Vault in dev mode + agent container with automatic secret injection
docker compose -f akash/docker-compose.yml up

# Verify the agent received its secrets
docker logs agentswarm-local
```

---

## Secret Rotation

### Rotate a single secret

```bash
# Update the value in Vault (creates a new version; old version is preserved)
vault kv patch secret/agentswarm/llm openai_api_key="sk-new-key-here"

# Running containers pick up the new value on next restart or token renewal.
# Force a rolling restart on Azure Container Apps:
az containerapp revision restart \
  --name agentswarm-prod-shard-000 \
  --resource-group agentswarm-rg \
  --revision $(az containerapp revision list -n agentswarm-prod-shard-000 \
    -g agentswarm-rg --query '[0].name' -o tsv)
```

### Rotate AppRole secret_id

AppRole `secret_id`s are single-use and self-rotating for Akash containers (a new one is generated per deployment). For Terraform:

```bash
# Revoke existing secret_ids
vault write -f auth/approle/role/terraform/secret-id-accessor/destroy \
  secret_id_accessor=<accessor>

# Generate a new one immediately before running Terraform
export TF_VAR_vault_approle_secret_id=$(vault write -wrap-ttl=10m \
  -field=wrapping_token -f auth/approle/role/terraform/secret-id)
```

### Rotate root token

```bash
# Generate a new root token (requires quorum of unseal key holders)
vault operator generate-root -init
# Follow the interactive process with 3 of 5 unseal key holders
```

---

## Security Checklist

- [ ] Vault TLS cert signed by a trusted CA (not self-signed)
- [ ] Auto-unseal configured (Azure Key Vault, AWS KMS, or GCP KMS)
- [ ] Root token revoked after initial bootstrap
- [ ] Audit logging enabled (`vault audit list`)
- [ ] Vault running as non-root with `IPC_LOCK` capability
- [ ] `/vault/data` on an encrypted volume (LUKS or cloud-managed)
- [ ] Vault agent container runs as UID 10001 (non-root)
- [ ] `VAULT_SECRET_ID` response-wrapped with short TTL (10 min)
- [ ] AppRole `secret_id_num_uses=1` for Akash containers
- [ ] Terraform state stored in encrypted remote backend
- [ ] `.env` and `terraform.tfvars` in `.gitignore`
- [ ] No secret values in CI logs (mask `VAULT_TOKEN` in your CI system)
- [ ] Vault access logs reviewed weekly

---

## Troubleshooting

### "permission denied" from Vault

Verify the token's policies:
```bash
vault token lookup
vault token capabilities secret/data/agentswarm/llm
```

### Container fails to start with "VAULT_ADDR must be set"

Check that `VAULT_ADDR` is correctly set in the Akash SDL or cloud-init script.

### "secret not found" / empty value

The path may not exist yet or may be a placeholder:
```bash
vault kv get secret/agentswarm/rpc
```
If you see `_placeholder`, re-run `seed-secrets.sh` for that path.

### Vault sealed after restart

If not using auto-unseal:
```bash
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>
```

### Terraform "Error: no auth method" with AppRole

Ensure `VAULT_ADDR` and `VAULT_TOKEN` (not `VAULT_ROLE_ID`/`VAULT_SECRET_ID`) are set when running Terraform. Terraform uses the Vault provider directly; the AppRole exchange is a pre-step done in your CI script before invoking `terraform`.

---

## File Map

```
vault/
├── config/vault.hcl               Vault server configuration
├── policies/
│   ├── agentswarm-admin.hcl       Full read/write (human operators)
│   ├── terraform.hcl              Read-only: cloud/* + rpc (Terraform)
│   ├── akash-runtime.hcl          Read-only: core, llm, rpc, depin, integrations
│   └── ci-deploy.hcl              Read-only: cloud/azure, integrations (CI/CD)
└── init/
    ├── bootstrap.sh               One-time setup: policies, AppRole, KV engine
    └── seed-secrets.sh            Interactive secret seeding template

terraform/
├── providers.tf                   Provider blocks — all creds from Vault
├── secrets.tf                     Vault KV v2 data sources
├── variables.tf                   Non-secret configuration
├── approle.tf                     AppRole variable declarations
├── main.tf                        Module composition
├── outputs.tf                     Non-sensitive outputs only
├── backend.tf                     Remote state options (choose one)
├── terraform.tfvars.example       Non-secret variable example
└── modules/
    ├── azure/                     Azure Container Apps + Storage
    ├── runpod/                    RunPod GPU inference pods
    ├── vultr/                     Vultr VPS nodes
    └── digitalocean/              DO Droplets + Spaces + PostgreSQL

akash/
├── Dockerfile                     Agent image with Vault CLI
├── entrypoint.sh                  AppRole auth → kv_export → exec agent
├── deploy.yaml                    Akash SDL (single shard template)
├── deploy-shards.sh               Deploy all 120 shards with fresh secret_ids
└── docker-compose.yml             Local dev: Vault + agent container
```

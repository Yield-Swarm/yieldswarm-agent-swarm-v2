# YieldSwarm AgentSwarm OS — Vault Secrets Setup Guide

> **Production-grade HashiCorp Vault integration.**  
> No secrets are hardcoded anywhere. Every key is fetched from Vault at runtime.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Deploy Vault Server](#3-deploy-vault-server)
4. [Initialize Vault](#4-initialize-vault)
5. [Enable Secrets Engines and Auth](#5-enable-secrets-engines-and-auth)
6. [Apply Policies](#6-apply-policies)
7. [Configure AppRole Auth](#7-configure-approle-auth)
8. [Seed Secrets into Vault](#8-seed-secrets-into-vault)
9. [Terraform — Pull Secrets from Vault](#9-terraform--pull-secrets-from-vault)
10. [Docker / Akash — Runtime Secret Injection](#10-docker--akash--runtime-secret-injection)
11. [Rotating Secrets](#11-rotating-secrets)
12. [Verifying the Setup](#12-verifying-the-setup)
13. [Secret Path Reference](#13-secret-path-reference)
14. [Security Hardening Checklist](#14-security-hardening-checklist)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       HashiCorp Vault                           │
│  KV v2 at secret/yieldswarm/<env>/<category>/<name>            │
│  AppRole auth • Transit encryption • Audit log                  │
└────────────┬───────────────────────────────┬───────────────────┘
             │ reads secrets                  │ reads secrets
             ▼                                ▼
    ┌─────────────────┐              ┌──────────────────────────┐
    │   Terraform     │              │   Vault Agent (sidecar)  │
    │  (plan/apply)   │              │   inside Docker / Akash  │
    │                 │              │                          │
    │  azurerm        │              │  Renders /vault/secrets/ │
    │  digitalocean   │              │  agent.env then execs    │
    │  vultr          │              │  the Python application  │
    │  runpod         │              └──────────────────────────┘
    └─────────────────┘
```

**The golden rule:** the only secret that ever appears outside Vault is the AppRole `secret_id`, and only briefly at deploy time. It is single-use and expires within 30 minutes.

---

## 2. Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| `vault` CLI | 1.17.x | https://developer.hashicorp.com/vault/downloads |
| `terraform` | 1.6.x | https://developer.hashicorp.com/terraform/downloads |
| `az` CLI | 2.60.x | https://learn.microsoft.com/en-us/cli/azure/install-azure-cli |
| `akash` CLI | 0.34.x | https://docs.akash.network/getting-started/install |
| `docker` | 24.x | https://docs.docker.com/get-docker/ |

```bash
# Verify installations
vault   version
terraform version
az      version
akash   version
docker  version
```

---

## 3. Deploy Vault Server

### Option A — Docker (local / single-node)

```bash
docker run -d \
  --name vault \
  --cap-add IPC_LOCK \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e AZURE_TENANT_ID=<your-tenant-id> \
  -e AZURE_CLIENT_ID=<your-sp-client-id> \
  -e AZURE_CLIENT_SECRET=<your-sp-client-secret> \
  -e VAULT_AZUREKEYVAULT_VAULT_NAME=<your-azure-kv-name> \
  -e VAULT_AZUREKEYVAULT_KEY_NAME=vault-unseal-key \
  -v /opt/vault/data:/vault/data \
  -v /opt/vault/tls:/vault/tls:ro \
  -v $(pwd)/vault/config/vault-server.hcl:/vault/config/vault.hcl:ro \
  -p 8200:8200 \
  hashicorp/vault:1.17 \
  vault server -config=/vault/config/vault.hcl
```

### Option B — Azure Container Instance (production)

```bash
az container create \
  --resource-group yieldswarm-agents-rg \
  --name vault-server \
  --image hashicorp/vault:1.17 \
  --cpu 2 --memory 4 \
  --ports 8200 8201 \
  --environment-variables \
    AZURE_TENANT_ID=<tenant-id> \
    VAULT_AZUREKEYVAULT_VAULT_NAME=ys-vault-unseal-kv \
    VAULT_AZUREKEYVAULT_KEY_NAME=vault-unseal-key \
  --secure-environment-variables \
    AZURE_CLIENT_SECRET=<sp-secret> \
  --command-line "vault server -config=/vault/config/vault.hcl"
```

> **TLS:** Generate a certificate for `vault.yieldswarm.internal` and mount it at `/vault/tls/vault.crt` and `/vault/tls/vault.key`. For a self-signed CA, see `vault/setup/02-enable-engines.sh` (PKI engine setup).

---

## 4. Initialize Vault

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_CACERT=/path/to/ca.crt   # omit if using public CA

# Run the init script (only once, on a fresh cluster)
cd /path/to/repo
bash vault/setup/01-init-vault.sh
```

The script prints the root token and writes `vault-init.json`.  
**Immediately after init:**

```bash
# 1. Save to Azure Key Vault
az keyvault secret set \
  --vault-name ys-vault-unseal-kv \
  --name vault-init-recovery \
  --file vault-init.json

# 2. Export the root token for subsequent steps
export VAULT_TOKEN=$(python3 -c \
  "import json; print(json.load(open('vault-init.json'))['root_token'])")

# 3. Shred the local file
shred -u vault-init.json
```

---

## 5. Enable Secrets Engines and Auth

```bash
# Enables: KV v2, Transit, PKI, AppRole auth, audit log
bash vault/setup/02-enable-engines.sh
```

Expected output:
```
[02] Enabled: secret/ (kv)
[02] Enabled: transit/ (transit)
[02] Enabled: pki/ (pki)
[02] Enabled auth: approle/ (approle)
[02] Audit log enabled at /vault/logs/audit.log
[02] PKI root CA generated.
```

---

## 6. Apply Policies

```bash
# Run from repository root
bash vault/setup/03-write-policies.sh
```

Policies applied (from `vault/policies/`):

| Policy | Purpose |
|--------|---------|
| `admin` | Break-glass human operator — all access |
| `terraform` | CI/CD Terraform runs — read infra credentials + RPC |
| `akash-agents` | Akash container agents — read all operational secrets |
| `runpod` | RunPod GPU workers — read LLM + RPC + monitoring |
| `vultr` | Vultr-hosted services — read core + monitoring |
| `digitalocean` | DO-hosted services — read core + monitoring |
| `rpc-readonly` | Any service needing only RPC access |

---

## 7. Configure AppRole Auth

```bash
# Creates roles: terraform, akash-agents, runpod, vultr, digitalocean
bash vault/setup/04-configure-auth.sh
```

Then generate Role IDs and initial Secret IDs:

```bash
bash vault/setup/05-create-role-ids.sh
```

This writes two files:
- `role-ids.env` — **non-sensitive**, commit to CI env vars
- `secret-ids.env` — **sensitive**, upload to CI secrets then shred

```bash
# Upload role_ids to GitHub Actions (non-secret)
gh secret set VAULT_ROLE_ID_TERRAFORM        --body "$(grep TERRAFORM role-ids.env | cut -d= -f2)"
gh secret set VAULT_ROLE_ID_AKASH_AGENTS     --body "$(grep AKASH_AGENTS role-ids.env | cut -d= -f2)"

# Upload secret_ids to GitHub Actions (encrypted secrets)
gh secret set VAULT_SECRET_ID_TERRAFORM      --body "$(grep TERRAFORM secret-ids.env | cut -d= -f2)"
gh secret set VAULT_SECRET_ID_AKASH_AGENTS   --body "$(grep AKASH_AGENTS secret-ids.env | cut -d= -f2)"

# Shred the local copies
shred -u role-ids.env secret-ids.env
```

---

## 8. Seed Secrets into Vault

```bash
# Copy the template — NEVER edit or commit the original
cp vault/setup/06-seed-secrets.sh vault/setup/06-seed-secrets.local.sh
```

Open `vault/setup/06-seed-secrets.local.sh` and replace every `CHANGEME_*` value with the real secret.

```bash
# Run it (VAULT_TOKEN must be set)
export VAULT_ENVIRONMENT=production
bash vault/setup/06-seed-secrets.local.sh

# Immediately shred the file
shred -u vault/setup/06-seed-secrets.local.sh
```

### Verifying secrets were written

```bash
vault kv get secret/yieldswarm/production/infra/azure
vault kv get secret/yieldswarm/production/infra/runpod
vault kv get secret/yieldswarm/production/infra/vultr
vault kv get secret/yieldswarm/production/infra/digitalocean
vault kv get secret/yieldswarm/production/rpc/solana
vault kv get secret/yieldswarm/production/llm/providers
vault kv get secret/yieldswarm/production/agents/core
```

---

## 9. Terraform — Pull Secrets from Vault

```bash
cd terraform/

# Copy and fill in non-secret config
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars (vault_addr, region, etc. — NO secrets)

# Authenticate to Vault as the terraform AppRole
VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="${VAULT_ROLE_ID_TERRAFORM}" \
  secret_id="${VAULT_SECRET_ID_TERRAFORM}")
export VAULT_TOKEN

# Init (sets up Azure backend — use ARM_* env vars for backend auth)
export ARM_CLIENT_ID=<backend-sp-client-id>
export ARM_CLIENT_SECRET=<backend-sp-secret>
export ARM_TENANT_ID=<tenant-id>
export ARM_SUBSCRIPTION_ID=<subscription-id>

terraform init

# Plan — Vault provider reads secrets; provider blocks use them
terraform plan -out=plan.tfplan

# Apply
terraform apply plan.tfplan
```

> **How it works:** `vault-data.tf` contains `data "vault_kv_secret_v2"` blocks for every provider. `providers.tf` configures `azurerm`, `digitalocean`, `vultr`, and `runpod` by referencing `data.vault_kv_secret_v2.<name>.data["<field>"]`. No secret ever appears in `.tfvars`, state file refs, or plan output (all outputs are `sensitive = true`).

---

## 10. Docker / Akash — Runtime Secret Injection

### Build the image

```bash
docker build \
  -f docker/Dockerfile \
  -t yieldswarm/agentswarm:2.0 \
  .

# Push to registry
docker push yieldswarm/agentswarm:2.0
```

### Test locally

```bash
# Authenticate as akash-agents AppRole
VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="${VAULT_ROLE_ID_AKASH_AGENTS}" \
  secret_id="$(vault write -field=secret_id -f auth/approle/role/akash-agents/secret-id)")

docker run --rm \
  -e VAULT_ADDR=https://vault.yieldswarm.internal:8200 \
  -e VAULT_ROLE_ID="${VAULT_ROLE_ID_AKASH_AGENTS}" \
  -e VAULT_SECRET_ID="$(vault write -field=secret_id -f auth/approle/role/akash-agents/secret-id)" \
  -e VAULT_ENVIRONMENT=production \
  yieldswarm/agentswarm:2.0
```

### Deploy to Akash

```bash
# 1. Generate a fresh single-use Secret ID for this deployment
FRESH_SECRET_ID=$(bash vault/setup/07-rotate-secret-id.sh akash-agents)

# 2. Set required env vars
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_ROLE_ID="${VAULT_ROLE_ID_AKASH_AGENTS}"
export VAULT_SECRET_ID="${FRESH_SECRET_ID}"
export VAULT_ENVIRONMENT=production

# 3. Substitute into the SDL (the SDL itself contains only placeholders)
envsubst < akash/deployment.yaml > /tmp/akash-deploy.yaml

# 4. Create the deployment
akash tx deployment create /tmp/akash-deploy.yaml \
  --from <your-wallet-keyname> \
  --chain-id akashnet-2 \
  --node https://rpc.akash.network:443 \
  --gas auto \
  --gas-adjustment 1.3 \
  --fees 5000uakt \
  -y

# 5. Shred the rendered SDL (contains the secret_id)
shred -u /tmp/akash-deploy.yaml

# 6. Unset sensitive env vars from shell
unset VAULT_SECRET_ID
```

---

## 11. Rotating Secrets

### Rotate a provider credential

```bash
# Example: rotate Azure client secret
vault kv patch secret/yieldswarm/production/infra/azure \
  client_secret="<new-azure-secret>"

# Verify
vault kv get secret/yieldswarm/production/infra/azure
```

### Rotate all AppRole Secret IDs (automated)

```bash
# Run before each deployment cycle
for role in terraform akash-agents runpod vultr digitalocean; do
  echo "Rotating secret_id for ${role}..."
  vault write -f "auth/approle/role/${role}/secret-id"
done
```

### Rotate the Vault root token (after initial setup)

```bash
# Revoke root token once all roles and policies are configured
vault token revoke "${VAULT_TOKEN}"
unset VAULT_TOKEN

# Future root access requires key holders to generate a new root token:
# vault operator generate-root -init
# (requires KEY_THRESHOLD custodians to provide their key shares)
```

---

## 12. Verifying the Setup

```bash
# Check Vault health
vault status

# Verify AppRole login works for each role
for role in terraform akash-agents runpod; do
  ROLE_ID=$(vault read -field=role_id "auth/approle/role/${role}/role-id")
  SECRET_ID=$(vault write -field=secret_id -f "auth/approle/role/${role}/secret-id")
  TOKEN=$(vault write -field=token auth/approle/login \
    role_id="${ROLE_ID}" secret_id="${SECRET_ID}")
  echo "Role ${role} login: OK (token=${TOKEN:0:8}...)"
  vault token revoke "${TOKEN}"
done

# Verify secrets are readable under the terraform policy
vault token create -policy=terraform -ttl=5m -field=token | \
  VAULT_TOKEN=$(cat) vault kv get secret/yieldswarm/production/infra/azure

# Check audit log
tail -f /vault/logs/audit.log | python3 -m json.tool
```

---

## 13. Secret Path Reference

All secrets live under `secret/yieldswarm/<environment>/` in KV v2.

| Vault Path | Fields | Who reads it |
|-----------|--------|--------------|
| `infra/azure` | `client_id`, `client_secret`, `tenant_id`, `subscription_id` | `terraform` |
| `infra/runpod` | `api_key`, `vault_role_id`, `vault_secret_id` | `terraform` |
| `infra/vultr` | `api_key`, `vault_role_id`, `vault_secret_id` | `terraform` |
| `infra/digitalocean` | `api_token`, `vault_role_id`, `vault_secret_id` | `terraform` |
| `rpc/solana` | `primary_url`, `helius_api_key`, `birdeye_api_key`, `jupiter_api_key`, `raydium_api_key`, `dexscreener_api_key`, `solscan_api_key`, `failover_list` | `terraform`, `akash-agents` |
| `blockchain/keys` | `pump_fun_deploy_key`, `ton_api_key`, `tao_subnet_key`, `helix_bridge_key`, `zec_shielded_key`, `erc4337_bundler_key`, `bittensor_staking_key` | `akash-agents` |
| `agents/core` | `master_key`, `kimiclaw_consensus_key`, `wallet_encryption_key`, `tee_signing_key`, `database_encryption_key` | `akash-agents` |
| `llm/providers` | `grok_api_key`, `openai_api_key`, `gemini_api_key`, `anthropic_api_key`, `arena_key` | `akash-agents`, `runpod` |
| `depin/hardware` | `helium_hotspot_keys`, `gpu_cluster_keys`, `grass_node_keys`, `smartthings_bridge_token`, `utility_api_key` | `akash-agents` |
| `integrations/productivity` | `notion_api_key`, `linear_api_key`, `vercel_api_token`, `github_token`, `sp_api_key`, `fsd_data_feed_key`, `tesla_integration_token` | `terraform`, `akash-agents` |
| `integrations/social` | `telegram_bot_token`, `x_api_keys`, `meta_ads_token` | `akash-agents` |
| `integrations/payments` | `ud_api_key`, `filecoin_storage_key` | `akash-agents` |
| `monitoring/config` | `prometheus_url`, `error_webhook`, `zkml_verifier_key` | `akash-agents`, `runpod`, `vultr`, `digitalocean` |

---

## 14. Security Hardening Checklist

- [ ] **Root token revoked** after initial policy and auth setup
- [ ] **Auto-unseal configured** via Azure Key Vault RSA-HSM key
- [ ] **Audit log enabled** (`vault audit enable file ...`)
- [ ] **TLS 1.3** enforced on the Vault listener
- [ ] **Vault UI disabled** in production (`ui = false` in `vault-server.hcl`)
- [ ] **AppRole secret_ids are single-use** (`secret_id_num_uses = 1`)
- [ ] **Secret IDs expire** within 30 minutes (`secret_id_ttl = 30m`)
- [ ] **`vault-init.json` never committed to git** (add to `.gitignore`)
- [ ] **`06-seed-secrets.local.sh` never committed** (add to `.gitignore`)
- [ ] **`secret-ids.env` never committed** (add to `.gitignore`)
- [ ] **Vault server not exposed to the public internet** (use private networking)
- [ ] **Network ACLs** restrict Vault access to known CIDRs
- [ ] **`VAULT_SECRET_ID` unset** from shell after writing to file
- [ ] **Prometheus metrics endpoint** requires authentication
- [ ] **Key custodians briefed** on unseal shard recovery procedure
- [ ] **Secret rotation schedule** defined (recommend 90-day maximum)
- [ ] **Break-glass procedure** documented and tested quarterly

---

> **Reminder:** The `.env.example` file is a reference catalogue for variable names only. In production, all values come from Vault. The `VAULT_SECRET_ID` variable in `.env.example` has been superseded by the AppRole workflow described above.

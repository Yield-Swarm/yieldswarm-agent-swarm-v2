# YieldSwarm — Vault Secrets Management Guide

Production-grade secret management using [HashiCorp Vault](https://developer.hashicorp.com/vault) for all YieldSwarm AgentSwarm OS credentials.

---

## Table of Contents

1. [Architecture overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Install and start Vault](#3-install-and-start-vault)
4. [Initialize and unseal Vault](#4-initialize-and-unseal-vault)
5. [Run the setup script](#5-run-the-setup-script)
6. [Populate real secrets](#6-populate-real-secrets)
7. [Terraform: pull secrets at plan/apply time](#7-terraform-pull-secrets-at-planapply-time)
8. [Akash: runtime secret injection](#8-akash-runtime-secret-injection)
9. [Build and push the Docker image](#9-build-and-push-the-docker-image)
10. [Rotate secrets](#10-rotate-secrets)
11. [Secret paths reference](#11-secret-paths-reference)
12. [Security checklist](#12-security-checklist)

---

## 1. Architecture overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Vault Cluster                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  KV v2: secret/yieldswarm/                              │   │
│  │    azure · runpod · vultr · do · rpc · llm              │   │
│  │    core · blockchain · depin · integrations · monitoring│   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ AppRole      │  │ AppRole      │  │ AppRole              │  │
│  │ terraform    │  │ agents       │  │ akash                │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────────┘  │
└─────────┼─────────────────┼───────────────────┼───────────────┘
          │                 │                   │
    ┌─────┴──────┐   ┌──────┴────────┐   ┌──────┴──────┐
    │ Terraform  │   │ Agent process │   │ Akash       │
    │ plan/apply │   │ (Azure/Vultr/ │   │ container   │
    │            │   │  DO/RunPod)   │   │ entrypoint  │
    └────────────┘   └───────────────┘   └─────────────┘
```

**Key design principles:**
- No secret ever appears in source code, environment files, or CI/CD logs
- Every workload has a narrow-scope AppRole (least-privilege)
- Token lifetimes are short; Vault Agent handles renewal transparently
- Rotation: update the secret in Vault → restart the workload → done

---

## 2. Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| `vault` CLI | 1.15 | [releases.hashicorp.com/vault](https://releases.hashicorp.com/vault/) |
| `terraform` | 1.6 | [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| `docker` | 24 | [docs.docker.com/engine/install](https://docs.docker.com/engine/install/) |
| `jq` | 1.6 | `apt install jq` / `brew install jq` |
| `curl` | any | pre-installed on most systems |

---

## 3. Install and start Vault

### Option A — Production (Integrated Raft, recommended)

```bash
# Install Vault on the server
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y vault

# Create required directories
sudo mkdir -p /opt/vault/{data,tls,logs}
sudo chown -R vault:vault /opt/vault

# Place TLS certificate and key in /opt/vault/tls/

# Deploy the server config
sudo cp vault/config/vault-server.hcl /etc/vault.d/vault.hcl
sudo systemctl enable vault
sudo systemctl start vault
```

### Option B — Development only (in-memory, no TLS)

```bash
vault server -dev -dev-root-token-id="dev-root-token" &
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=dev-root-token
# Skip steps 4 (init/unseal) — dev server is pre-initialized
```

---

## 4. Initialize and unseal Vault

**Run once on first deployment.**

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200

# Initialize — generates unseal keys and initial root token
vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > /tmp/vault-init.json

# Print (and immediately store offline) the unseal keys and root token
cat /tmp/vault-init.json | jq '.unseal_keys_b64'
cat /tmp/vault-init.json | jq -r '.root_token'

# ⚠️  Store the unseal keys in a secure offline location (e.g. split
# between multiple trusted keyholders). Delete /tmp/vault-init.json
# after you have copied the values to your secure store.

# Unseal with 3 of the 5 keys
vault operator unseal <KEY_1>
vault operator unseal <KEY_2>
vault operator unseal <KEY_3>

# Confirm Vault is unsealed
vault status
```

> **Production:** Use AWS KMS, Azure Key Vault, or GCP CKMS auto-unseal so you
> never need manual unseal keys. See `vault/config/vault-server.hcl` for the
> `seal` block configuration.

---

## 5. Run the setup script

The setup script is idempotent — safe to re-run at any time.

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=<root-or-admin-token>

bash vault/setup.sh
```

What it does:
1. Enables KV v2 secrets engine at `secret/`
2. Enables JSON file audit logging to `/opt/vault/logs/audit.log`
3. Writes placeholder (`REPLACE_ME`) values for all secret paths
4. Uploads all four ACL policies from `vault/policies/`
5. Enables the AppRole auth method
6. Creates three AppRole roles: `yieldswarm-terraform`, `yieldswarm-agents`, `yieldswarm-akash`
7. Prints all three Role IDs

---

## 6. Populate real secrets

Replace every `REPLACE_ME` value with the actual secret. Use `vault kv put` to
overwrite a path or `vault kv patch` to update individual fields.

### 6a. Azure

```bash
vault kv put secret/yieldswarm/azure \
  subscription_id="<azure-subscription-id>" \
  tenant_id="<azure-tenant-id>" \
  client_id="<azure-service-principal-client-id>" \
  client_secret="<azure-service-principal-client-secret>" \
  resource_group="yieldswarm-prod"
```

### 6b. RunPod

```bash
vault kv put secret/yieldswarm/runpod \
  api_key="<runpod-api-key>" \
  endpoint_url="https://api.runpod.io/graphql"
```

### 6c. Vultr

```bash
vault kv put secret/yieldswarm/vultr \
  api_key="<vultr-api-key>"
```

### 6d. DigitalOcean

```bash
vault kv put secret/yieldswarm/do \
  token="<do-personal-access-token>" \
  spaces_access_key="<spaces-access-key>" \
  spaces_secret_key="<spaces-secret-key>" \
  region="nyc3"
```

### 6e. RPC endpoints

```bash
vault kv put secret/yieldswarm/rpc \
  solana_rpc_url="https://api.mainnet-beta.solana.com" \
  helius_api_key="<helius-api-key>" \
  birdeye_api_key="<birdeye-api-key>" \
  jupiter_api_key="<jupiter-api-key>" \
  raydium_api_key="<raydium-api-key>" \
  ton_api_key="<ton-api-key>" \
  tao_subnet_key="<tao-subnet-key>" \
  helix_chain_bridge_key="<helix-bridge-key>" \
  zec_shielded_key="<zec-shielded-key>" \
  erc4337_bundler_key="<erc4337-bundler-key>" \
  failover_rpc_list='["https://rpc1.example.com","https://rpc2.example.com"]'
```

### 6f. LLM keys

```bash
vault kv put secret/yieldswarm/llm \
  grok_api_key="<grok-api-key>" \
  openai_api_key="<openai-api-key>" \
  gemini_api_key="<gemini-api-key>" \
  anthropic_api_key="<anthropic-api-key>"
```

### 6g. Core auth

```bash
vault kv put secret/yieldswarm/core \
  master_key="$(openssl rand -hex 32)" \
  kimiclaw_key="<kimiclaw-consensus-key>" \
  wallet_encryption_key="$(openssl rand -hex 32)" \
  tee_signing_key="<tee-signing-key>" \
  db_encryption_key="$(openssl rand -hex 32)"
```

### 6h. Remaining paths

```bash
# Integrations
vault kv put secret/yieldswarm/integrations \
  notion_api_key="<notion-key>" \
  linear_api_key="<linear-key>" \
  vercel_api_token="<vercel-token>" \
  github_token="<github-token>" \
  telegram_bot_token="<telegram-token>" \
  ud_api_key="<unstoppable-domains-key>" \
  wise_business_email="<wise-email>" \
  meta_ads_token="<meta-token>"

# Blockchain
vault kv put secret/yieldswarm/blockchain \
  pump_fun_deploy_key="<pump-fun-key>" \
  apn_mint_address="8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump" \
  raydium_pool_id="<raydium-pool-id>" \
  lp_token_address="<lp-token-address>"

# DePIN
vault kv put secret/yieldswarm/depin \
  helium_hotspot_keys='["<hotspot-key-1>"]' \
  gpu_cluster_keys='["<runpod-key>","<rtx4090-key>"]' \
  grass_node_keys='["<grass-node-key>"]' \
  smartthings_bridge_token="<smartthings-token>" \
  utility_api_key="<utility-api-key>"

# Monitoring
vault kv put secret/yieldswarm/monitoring \
  prometheus_url="<prometheus-url>" \
  error_webhook="<webhook-url>" \
  filecoin_storage_key="<filecoin-key>" \
  zkml_verifier_key="<zkml-key>" \
  dexscreener_api_key="<dexscreener-key>" \
  solscan_api_key="<solscan-key>" \
  admin_account_segment="<segment-key>" \
  quarantined_arena_key="<arena-key>"

# Akash deployment config
vault kv put secret/yieldswarm/akash \
  wallet_address="<akash-wallet-address>" \
  key_name="yieldswarm-deployer" \
  chain_id="akashnet-2" \
  node_rpc="https://rpc.akash.forbole.com:443"
```

### Verify all paths are populated

```bash
for path in azure runpod vultr do rpc llm core integrations blockchain depin monitoring akash; do
  echo -n "secret/yieldswarm/${path}: "
  vault kv get -format=json "secret/yieldswarm/${path}" \
    | jq '[.data.data | to_entries[] | select(.value == "REPLACE_ME") | .key] | if length == 0 then "OK" else "MISSING: " + join(", ") end' -r
done
```

---

## 7. Terraform: pull secrets at plan/apply time

### 7a. Get the Terraform AppRole credentials

```bash
# Role ID (non-sensitive, safe to store in CI)
vault read -field=role_id auth/approle/role/yieldswarm-terraform/role-id

# Secret ID (sensitive — treat like a password, store in CI secrets)
vault write -format=json -f \
  auth/approle/role/yieldswarm-terraform/secret-id \
  | jq -r '.data.secret_id'
```

### 7b. Configure Terraform

```bash
cd terraform

# Copy example vars
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
#   vault_address = "https://vault.yieldswarm.internal:8200"
#   (everything else stays as-is — credentials come from Vault)

# Supply secrets as environment variables (never in tfvars)
export TF_VAR_vault_role_id="<role-id-from-above>"
export TF_VAR_vault_secret_id="<secret-id-from-above>"

terraform init
terraform plan
terraform apply
```

### 7c. CI/CD integration (GitHub Actions example)

```yaml
- name: Terraform Apply
  env:
    TF_VAR_vault_address: ${{ secrets.VAULT_ADDR }}
    TF_VAR_vault_role_id: ${{ secrets.VAULT_TF_ROLE_ID }}
    TF_VAR_vault_secret_id: ${{ secrets.VAULT_TF_SECRET_ID }}
  run: |
    cd terraform
    terraform init
    terraform apply -auto-approve
```

---

## 8. Akash: runtime secret injection

### 8a. Get the Akash AppRole credentials

```bash
# Role ID
vault read -field=role_id auth/approle/role/yieldswarm-akash/role-id

# Secret ID
vault write -format=json -f \
  auth/approle/role/yieldswarm-akash/secret-id \
  | jq -r '.data.secret_id'
```

### 8b. Edit the SDL

Open `akash/deploy.yaml` and replace the two placeholder values:

```yaml
env:
  - VAULT_ADDR=https://vault.yieldswarm.internal:8200
  - VAULT_ROLE_ID=<INSERT_ROLE_ID>          # paste Role ID here
  - VAULT_SECRET_ID=<INSERT_SECRET_ID>      # paste Secret ID here
```

> **Never commit a filled-in `deploy.yaml` with real credentials.**
> Generate a fresh Secret ID per deployment and treat the file as
> ephemeral — it is consumed by the Akash CLI once and then discarded.

### 8c. Deploy to Akash

```bash
# Install Akash CLI (if not present)
curl -sSfL https://raw.githubusercontent.com/akash-network/node/master/install.sh | sh

# Create wallet and fund it with AKT
akash keys add yieldswarm-deployer
# Send AKT to the wallet address shown

# Submit deployment
akash tx deployment create akash/deploy.yaml \
  --from yieldswarm-deployer \
  --chain-id akashnet-2 \
  --node https://rpc.akash.forbole.com:443 \
  --fees 5000uakt \
  --gas auto

# Watch for bids
akash query market bid list \
  --owner $(akash keys show yieldswarm-deployer -a) \
  --node https://rpc.akash.forbole.com:443

# Accept a bid (replace DSEQ, GSEQ, OSEQ, PROVIDER with actual values)
akash tx market lease create \
  --dseq <DSEQ> --gseq <GSEQ> --oseq <OSEQ> \
  --provider <PROVIDER> \
  --from yieldswarm-deployer \
  --chain-id akashnet-2 \
  --node https://rpc.akash.forbole.com:443 \
  --fees 5000uakt
```

---

## 9. Build and push the Docker image

```bash
# Build (from repo root)
docker build \
  -t yieldswarm/agentswarm:latest \
  -f docker/Dockerfile \
  .

# Tag with version
docker tag yieldswarm/agentswarm:latest \
  yieldswarm/agentswarm:$(git rev-parse --short HEAD)

# Push to your registry
docker push yieldswarm/agentswarm:latest
docker push yieldswarm/agentswarm:$(git rev-parse --short HEAD)

# To use Azure Container Registry:
#   REGISTRY=$(terraform -chdir=terraform output -raw azure_container_registry_login_server)
#   az acr login --name "${REGISTRY%%.*}"
#   docker tag yieldswarm/agentswarm:latest "${REGISTRY}/agentswarm:latest"
#   docker push "${REGISTRY}/agentswarm:latest"
```

---

## 10. Rotate secrets

### Single secret field

```bash
# Update one field without touching others
vault kv patch secret/yieldswarm/llm \
  openai_api_key="<new-key>"

# Restart affected workloads to pick up the new value:
#   Akash: redeploy with a fresh VAULT_SECRET_ID
#   Azure Container App: az containerapp revision restart ...
#   RunPod/Vultr/DO: restart the container/VM
```

### AppRole Secret ID rotation (scheduled — run weekly)

```bash
# Terraform role
vault write -format=json -f \
  auth/approle/role/yieldswarm-terraform/secret-id \
  | jq -r '.data.secret_id'
# Update CI/CD secret VAULT_TF_SECRET_ID with the new value

# Akash role
vault write -format=json -f \
  auth/approle/role/yieldswarm-akash/secret-id \
  | jq -r '.data.secret_id'
# Update VAULT_SECRET_ID in akash/deploy.yaml and redeploy
```

### Revoke a compromised token immediately

```bash
vault token revoke <token>
# Or revoke all tokens for a role:
vault token revoke -mode=path auth/approle/login
```

---

## 11. Secret paths reference

| Vault path | Fields | Used by |
|------------|--------|---------|
| `secret/yieldswarm/azure` | `subscription_id`, `tenant_id`, `client_id`, `client_secret`, `resource_group` | Terraform (Azure provider) |
| `secret/yieldswarm/runpod` | `api_key`, `endpoint_url` | Terraform (RunPod provider) |
| `secret/yieldswarm/vultr` | `api_key` | Terraform (Vultr provider) |
| `secret/yieldswarm/do` | `token`, `spaces_access_key`, `spaces_secret_key`, `region` | Terraform (DO provider) |
| `secret/yieldswarm/rpc` | `solana_rpc_url`, `helius_api_key`, `birdeye_api_key`, `jupiter_api_key`, `raydium_api_key`, `ton_api_key`, `tao_subnet_key`, `helix_chain_bridge_key`, `zec_shielded_key`, `erc4337_bundler_key`, `failover_rpc_list` | Terraform + Akash agents |
| `secret/yieldswarm/llm` | `grok_api_key`, `openai_api_key`, `gemini_api_key`, `anthropic_api_key` | Akash agents |
| `secret/yieldswarm/core` | `master_key`, `kimiclaw_key`, `wallet_encryption_key`, `tee_signing_key`, `db_encryption_key` | Akash agents |
| `secret/yieldswarm/blockchain` | `pump_fun_deploy_key`, `apn_mint_address`, `raydium_pool_id`, `lp_token_address` | Akash agents |
| `secret/yieldswarm/depin` | `helium_hotspot_keys`, `gpu_cluster_keys`, `grass_node_keys`, `smartthings_bridge_token`, `utility_api_key` | Akash agents |
| `secret/yieldswarm/integrations` | `notion_api_key`, `linear_api_key`, `vercel_api_token`, `github_token`, `telegram_bot_token`, `ud_api_key`, `wise_business_email`, `meta_ads_token` | Akash agents + Terraform |
| `secret/yieldswarm/monitoring` | `prometheus_url`, `error_webhook`, `filecoin_storage_key`, `zkml_verifier_key`, `dexscreener_api_key`, `solscan_api_key`, `admin_account_segment`, `quarantined_arena_key` | Akash agents + Terraform |
| `secret/yieldswarm/akash` | `wallet_address`, `key_name`, `chain_id`, `node_rpc` | Akash deployment |

---

## 12. Security checklist

- [ ] Vault TLS configured with a valid certificate (not self-signed in prod)
- [ ] Auto-unseal configured (AWS KMS / Azure Key Vault / GCP CKMS)
- [ ] Unseal keys split across multiple trusted keyholders (if manual unseal)
- [ ] Root token revoked after initial setup: `vault token revoke <root-token>`
- [ ] Audit log enabled and shipping to SIEM / S3
- [ ] No `REPLACE_ME` values remain in any secret path (see verification command in §6)
- [ ] `terraform.tfvars` is gitignored and never committed
- [ ] `deploy.yaml` with real credentials is never committed
- [ ] AppRole Secret IDs rotated on a weekly schedule
- [ ] Vault UI restricted to VPN/internal network (firewall rule)
- [ ] `vault_skip_tls_verify` is `false` in all production configs
- [ ] Container runs as non-root user (`agentswarm`, UID 10001)
- [ ] `VAULT_ROLE_ID` and `VAULT_SECRET_ID` are unset from env after login (entrypoint.sh handles this automatically)
- [ ] Secret IDs have `secret_id_num_uses = 0` (unlimited; rotate on schedule rather than per-use)
- [ ] Token TTLs reviewed: Terraform 1 h, Agents/Akash 24 h renewable to 168 h

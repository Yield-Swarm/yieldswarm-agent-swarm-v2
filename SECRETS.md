# YieldSwarm AgentSwarm OS v2 — Secrets Setup Guide

This document is the single source of truth for secrets management across the entire YieldSwarm stack.
**Follow every step in order.** Never skip a section.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Install and Start Vault](#3-install-and-start-vault)
4. [Initialize and Unseal Vault](#4-initialize-and-unseal-vault)
5. [Run the Automated Setup Script](#5-run-the-automated-setup-script)
6. [Store Your Real Secrets](#6-store-your-real-secrets)
7. [Verify Vault Access](#7-verify-vault-access)
8. [Terraform Integration](#8-terraform-integration)
9. [Docker Local Testing](#9-docker-local-testing)
10. [Akash Deployment](#10-akash-deployment)
11. [CI/CD — GitHub Actions](#11-cicd--github-actions)
12. [Rotating Secrets](#12-rotating-secrets)
13. [Disaster Recovery](#13-disaster-recovery)
14. [Security Checklist](#14-security-checklist)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     HashiCorp Vault (KV v2)                         │
│                                                                     │
│  secret/azure/credentials      ← azurerm provider auth            │
│  secret/runpod/credentials     ← RunPod GPU pod creation           │
│  secret/vultr/credentials      ← Vultr provider auth               │
│  secret/digitalocean/credentials ← DigitalOcean provider auth     │
│  secret/rpc/solana             ← Helius, Jupiter, Birdeye, etc.   │
│  secret/rpc/evm                ← TON, ERC-4337, Helix, ZEC        │
│  secret/agents/master          ← LLM API keys, encryption keys    │
│  secret/agents/blockchain      ← Wallet / DeFi keys               │
│  secret/agents/depin           ← Helium, Grass, GPU cluster keys  │
│  secret/agents/integrations    ← Notion, Linear, GitHub, Telegram │
└────────────────────┬────────────────────────────────────────────────┘
                     │  AppRole login (role_id + secret_id)
          ┌──────────┴──────────┐
          │                     │
  ┌───────▼──────┐    ┌─────────▼──────────────┐
  │  Terraform   │    │  Akash / Docker Agent  │
  │              │    │                        │
  │ vault-env.sh │    │  entrypoint.sh         │
  │ exports ARM_*│    │  fetches ALL secrets   │
  │ VULTR_* etc. │    │  then revokes token    │
  │ then runs tf │    │  then exec app         │
  └──────────────┘    └────────────────────────┘
```

**Security invariants:**
- No real secret ever appears in any file committed to git.
- Provider credentials exist only in Vault and in-process environment variables.
- Vault tokens are ephemeral (TTL ≤ 2h) and revoked immediately after use.
- The only things in Akash SDL / docker run env are `VAULT_ADDR`, `VAULT_ROLE_ID`, `VAULT_SECRET_ID`.

---

## 2. Prerequisites

Install these tools before proceeding:

```bash
# Vault CLI
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# Terraform
sudo apt install terraform

# jq
sudo apt install jq

# Docker
curl -fsSL https://get.docker.com | sh

# Akash CLI (provider-services)
curl https://raw.githubusercontent.com/akash-network/provider/main/install.sh | sh

# Verify
vault   version
terraform version
jq      --version
docker  --version
provider-services version
```

---

## 3. Install and Start Vault

### Option A — Self-hosted (recommended for production)

```bash
# Create Vault config directory
sudo mkdir -p /etc/vault.d /opt/vault/data

# Create server config
sudo tee /etc/vault.d/vault.hcl > /dev/null <<'EOF'
ui            = true
disable_mlock = false

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-node-1"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/tls/vault.crt"
  tls_key_file  = "/etc/vault.d/tls/vault.key"
}

api_addr     = "https://vault.yieldswarm.io:8200"
cluster_addr = "https://vault.yieldswarm.io:8201"
EOF

# Start Vault as a systemd service
sudo tee /etc/systemd/system/vault.service > /dev/null <<'EOF'
[Unit]
Description=HashiCorp Vault
After=network-online.target
Wants=network-online.target

[Service]
User=vault
Group=vault
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
LimitMEMLOCK=infinity
AmbientCapabilities=CAP_IPC_LOCK

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now vault
```

### Option B — HCP Vault (managed, zero ops)

1. Sign up at https://portal.cloud.hashicorp.com
2. Create a new Vault cluster (Plus tier recommended for production)
3. Note your `VAULT_ADDR` (e.g. `https://yieldswarm.vault.hashicorp.cloud:8200`)
4. Skip §4 — HCP handles initialization and unsealing automatically
5. Create an admin token in the HCP console and continue from §5

### Option C — Docker (development only)

```bash
docker run -d \
  --name vault-dev \
  --cap-add IPC_LOCK \
  -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=root-dev-token-change-in-prod \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  hashicorp/vault:1.17 server -dev

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root-dev-token-change-in-prod"
```

> **Warning:** Dev mode stores data in-memory only. Never use for production.

---

## 4. Initialize and Unseal Vault

> Skip this section if using HCP Vault (Option B above).

```bash
export VAULT_ADDR="https://vault.yieldswarm.io:8200"

# Initialize — produces unseal keys and root token
vault operator init -key-shares=5 -key-threshold=3 -format=json > /tmp/vault-init.json

# IMPORTANT: Save the output of the above command to a secure offline location
# (printed USB drive, printed paper in a fireproof safe, or HSM).
# You need 3 of the 5 unseal keys to unseal Vault after every restart.

# Extract and display (for your records — then delete from disk)
cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[]'
cat /tmp/vault-init.json | jq -r '.root_token'

# Unseal with 3 of the 5 keys
vault operator unseal $(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[0]')
vault operator unseal $(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[1]')
vault operator unseal $(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[2]')

# Authenticate with root token
export VAULT_TOKEN=$(cat /tmp/vault-init.json | jq -r '.root_token')

# Verify
vault status

# Delete init file from disk (keys are in your offline safe)
shred -u /tmp/vault-init.json
```

---

## 5. Run the Automated Setup Script

This script:
- Enables KV v2 at `secret/`
- Applies all three policies (`admin`, `terraform`, `akash-agent`)
- Enables AppRole auth
- Creates AppRole roles for Terraform and Akash Agent
- Scaffolds all secret paths with `REPLACE_ME` placeholders

```bash
export VAULT_ADDR="https://vault.yieldswarm.io:8200"
export VAULT_TOKEN="<your-root-or-admin-token>"

bash vault/setup.sh
```

**Save the output.** It prints your `VAULT_ROLE_ID` and `VAULT_SECRET_ID` for both
AppRole roles. Store them immediately in a password manager or CI secrets.

---

## 6. Store Your Real Secrets

Replace every `REPLACE_ME` placeholder with real values.
**Use the exact commands below — copy, paste, fill in values.**

### 6.1 Azure Credentials

Create an Azure service principal first:
```bash
az ad sp create-for-rbac \
  --name "yieldswarm-terraform" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

Store the output in Vault:
```bash
vault kv put secret/azure/credentials \
  subscription_id="<AZURE_SUBSCRIPTION_ID>" \
  client_id="<SERVICE_PRINCIPAL_APP_ID>" \
  client_secret="<SERVICE_PRINCIPAL_PASSWORD>" \
  tenant_id="<AZURE_TENANT_ID>"
```

### 6.2 RunPod Credentials

1. Log in at https://www.runpod.io/console/user/settings
2. Click **API Keys** → **+ API Key**
3. Copy the key

```bash
vault kv put secret/runpod/credentials \
  api_key="<RUNPOD_API_KEY>"
```

### 6.3 Vultr Credentials

1. Log in at https://my.vultr.com/settings/#settingsapi
2. Generate a Personal Access Token

```bash
vault kv put secret/vultr/credentials \
  api_key="<VULTR_API_KEY>"
```

### 6.4 DigitalOcean Credentials

1. Log in at https://cloud.digitalocean.com/account/api/tokens
2. Generate a new token (read + write)
3. For Spaces, create access keys at https://cloud.digitalocean.com/account/api/spaces-keys

```bash
vault kv put secret/digitalocean/credentials \
  token="<DO_API_TOKEN>" \
  spaces_access_key="<DO_SPACES_ACCESS_KEY>" \
  spaces_secret_key="<DO_SPACES_SECRET_KEY>"
```

### 6.5 Solana / Blockchain RPC Secrets

```bash
vault kv put secret/rpc/solana \
  endpoint="<HELIUS_OR_QUICKNODE_SOLANA_RPC_URL>" \
  helius_api_key="<HELIUS_API_KEY>" \
  birdeye_api_key="<BIRDEYE_API_KEY>" \
  jupiter_api_key="<JUPITER_API_KEY>" \
  raydium_api_key="<RAYDIUM_API_KEY>" \
  pump_fun_deploy_key="<PUMP_FUN_DEPLOY_PRIVATE_KEY>" \
  solscan_api_key="<SOLSCAN_API_KEY>" \
  failover_rpc_list='["https://api.mainnet-beta.solana.com","https://rpc.ankr.com/solana"]'
```

### 6.6 EVM / Other Chain RPC Secrets

```bash
vault kv put secret/rpc/evm \
  ton_api_key="<TON_API_KEY>" \
  tao_subnet_key="<BITTENSOR_SUBNET_KEY>" \
  helix_chain_bridge_key="<HELIX_BRIDGE_KEY>" \
  zec_shielded_key="<ZEC_SHIELDED_PRIVATE_KEY>" \
  erc4337_bundler_key="<ERC4337_BUNDLER_API_KEY>"
```

### 6.7 Agent Master Keys

```bash
vault kv put secret/agents/master \
  agentswarm_master_key="$(openssl rand -hex 32)" \
  kimiclaw_consensus_key="$(openssl rand -hex 32)" \
  wallet_encryption_key="$(openssl rand -hex 32)" \
  tee_signing_key="$(openssl rand -hex 32)" \
  database_encryption_key="$(openssl rand -hex 32)" \
  grok_api_key="<GROK_API_KEY>" \
  openai_api_key="<OPENAI_API_KEY>" \
  gemini_api_key="<GEMINI_API_KEY>" \
  anthropic_api_key="<ANTHROPIC_API_KEY>"
```

> The `openssl rand -hex 32` commands generate cryptographically random 256-bit keys.
> Run them in a secure terminal; they are piped directly into Vault — never stored in shell history.

### 6.8 Blockchain / Wallet Secrets

```bash
vault kv put secret/agents/blockchain \
  apn_mint_address="8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump" \
  pump_fun_coin_id="8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump" \
  raydium_pool_id="<RAYDIUM_POOL_ID>" \
  lp_token_address="<LP_TOKEN_ADDRESS>" \
  ng64_bittensor_node_staking_key="<NG64_STAKING_KEY>" \
  zkml_verifier_key="<ZKML_VERIFIER_KEY>"
```

### 6.9 DePIN Node Keys

```bash
vault kv put secret/agents/depin \
  depin_helium_hotspot_keys='["<HOTSPOT_1_KEY>","<HOTSPOT_2_KEY>"]' \
  gpu_cluster_keys='["<RUNPOD_KEY_1>","<RTX4090_KEY>"]' \
  grass_node_keys='["<GRASS_NODE_1_KEY>"]' \
  smartthings_bridge_token="<SMARTTHINGS_TOKEN>" \
  colorado_power_permit_id="<PERMIT_ID>" \
  utility_api_key="<UTILITY_API_KEY>"
```

### 6.10 Integration API Keys

```bash
vault kv put secret/agents/integrations \
  notion_api_key="<NOTION_INTEGRATION_TOKEN>" \
  linear_api_key="<LINEAR_API_KEY>" \
  vercel_api_token="<VERCEL_TOKEN>" \
  github_token="<GITHUB_PAT>" \
  telegram_bot_token="<TELEGRAM_BOT_TOKEN>" \
  ud_api_key="<UNSTOPPABLE_DOMAINS_API_KEY>" \
  dexscreener_api="<DEXSCREENER_KEY>" \
  filecoin_storage_key="<FILECOIN_KEY>" \
  quarantined_llm_arena_key="<ARENA_KEY>"
```

---

## 7. Verify Vault Access

Confirm secrets are readable with the Terraform AppRole:

```bash
# Login as Terraform AppRole
VAULT_TF_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="<TERRAFORM_ROLE_ID>" \
  secret_id="<TERRAFORM_SECRET_ID>")

# Verify read access
VAULT_TOKEN="$VAULT_TF_TOKEN" vault kv get secret/azure/credentials
VAULT_TOKEN="$VAULT_TF_TOKEN" vault kv get secret/runpod/credentials
VAULT_TOKEN="$VAULT_TF_TOKEN" vault kv get secret/vultr/credentials
VAULT_TOKEN="$VAULT_TF_TOKEN" vault kv get secret/digitalocean/credentials
VAULT_TOKEN="$VAULT_TF_TOKEN" vault kv get secret/rpc/solana
VAULT_TOKEN="$VAULT_TF_TOKEN" vault kv get secret/rpc/evm

# Confirm write access is denied (should fail with permission denied)
VAULT_TOKEN="$VAULT_TF_TOKEN" vault kv put secret/azure/credentials subscription_id="test" \
  && echo "FAIL: write should be denied" || echo "OK: write correctly denied"

# Revoke the test token
VAULT_TOKEN="$VAULT_TF_TOKEN" vault token revoke -self
```

Confirm the Akash Agent AppRole:

```bash
VAULT_AGENT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="<AKASH_AGENT_ROLE_ID>" \
  secret_id="<AKASH_AGENT_SECRET_ID>")

# Should succeed
VAULT_TOKEN="$VAULT_AGENT_TOKEN" vault kv get secret/agents/master
VAULT_TOKEN="$VAULT_AGENT_TOKEN" vault kv get secret/rpc/solana

# Should fail (agent has no access to cloud credentials)
VAULT_TOKEN="$VAULT_AGENT_TOKEN" vault kv get secret/azure/credentials \
  && echo "FAIL: should be denied" || echo "OK: correctly denied"

VAULT_TOKEN="$VAULT_AGENT_TOKEN" vault token revoke -self
```

---

## 8. Terraform Integration

### 8.1 One-time Vault IaC bootstrap

Manage Vault configuration itself with Terraform:

```bash
export VAULT_ADDR="https://vault.yieldswarm.io:8200"
export VAULT_TOKEN="<admin-token>"

cd vault/terraform
terraform init
terraform plan
terraform apply
```

This creates/updates policies, AppRole roles, and the KV engine via code.

### 8.2 Running infrastructure Terraform

```bash
# Set AppRole credentials (store these in CI secrets — see §11)
export VAULT_ADDR="https://vault.yieldswarm.io:8200"
export VAULT_ROLE_ID="<TERRAFORM_ROLE_ID>"
export VAULT_SECRET_ID="<TERRAFORM_SECRET_ID>"

# Source the wrapper — it logs in to Vault and exports ARM_*, DIGITALOCEAN_TOKEN, etc.
source terraform/scripts/vault-env.sh

# Now run Terraform normally
cd terraform
terraform init
terraform plan -var="vault_addr=${VAULT_ADDR}"
terraform apply -var="vault_addr=${VAULT_ADDR}"
```

> **Never** run `terraform apply` without sourcing `vault-env.sh` first.
> The providers will silently fall back to empty credentials and likely fail or
> create resources with no auth configured.

### 8.3 Terraform state encryption

Add to `terraform/versions.tf` after choosing a backend:

```hcl
# S3 backend example with KMS encryption
backend "s3" {
  bucket         = "yieldswarm-tf-state"
  key            = "infra/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  kms_key_id     = "alias/yieldswarm-terraform-state"
  dynamodb_table = "yieldswarm-tf-locks"
}
```

Never use `backend "local"` in production — local state files contain plaintext secret values.

---

## 9. Docker Local Testing

Build and test the container locally before pushing to Akash:

```bash
# Build
docker build -t yieldswarm/agent-swarm:latest -f docker/Dockerfile .

# Generate a short-lived Akash Agent secret_id for testing
TEST_SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/akash-agent/secret-id)

# Run — only three env vars reach the container
docker run --rm \
  -e VAULT_ADDR="https://vault.yieldswarm.io:8200" \
  -e VAULT_ROLE_ID="<AKASH_AGENT_ROLE_ID>" \
  -e VAULT_SECRET_ID="${TEST_SECRET_ID}" \
  -p 8080:8080 \
  yieldswarm/agent-swarm:latest

# Verify the container started and secrets are available
docker exec -it <container-id> env | grep -E "OPENAI|SOLANA|HELIUS"
# Expected: values are populated (not REPLACE_ME or empty)
```

### Verify nothing is hardcoded

```bash
# These searches should return zero results — if any match, fix them before deploying.
grep -r "REPLACE_ME"      docker/ akash/ terraform/ vault/setup.sh  # scaffolding only
grep -rE "(sk-|xai-|gsk_)" agents/ docker/ akash/                  # LLM API key patterns
grep -rE "[a-f0-9]{64}"   agents/ docker/ akash/                   # 256-bit hex keys
```

---

## 10. Akash Deployment

### 10.1 Generate a wrapped secret_id for Akash

Each deployment gets its own secret_id. Use a wrapped token so the secret_id
is never exposed in transit — it can only be unwrapped once:

```bash
# Generate a wrapped secret_id (5-minute TTL, single-use unwrap)
WRAPPED=$(vault write -wrap-ttl=300s -field=wrapping_token \
  -f auth/approle/role/akash-agent/secret-id)

# Unwrap immediately to get the actual secret_id
AKASH_SECRET_ID=$(vault unwrap -field=secret_id "$WRAPPED")
```

### 10.2 Update deploy.yaml

Edit `akash/deploy.yaml` and replace:
```
- VAULT_ROLE_ID=REPLACE_WITH_AKASH_AGENT_ROLE_ID
- VAULT_SECRET_ID=REPLACE_WITH_AKASH_AGENT_SECRET_ID
```

with your real values. **Do not commit this file after adding real values** — use
the Akash Console or CLI to pass environment variables at deploy time.

### 10.3 Deploy to Akash

```bash
# Create the deployment
provider-services tx deployment create akash/deploy.yaml \
  --from <your-wallet-key-name> \
  --chain-id akashnet-2 \
  --node https://rpc.akash.network:443 \
  --keyring-backend os \
  -y

# Get the DSEQ from the output and wait for bids
provider-services query market bid list --owner <your-address> --dseq <DSEQ>

# Accept the best bid and create the lease
provider-services tx market lease create \
  --dseq <DSEQ> \
  --gseq 1 \
  --oseq 1 \
  --provider <PROVIDER_ADDRESS> \
  --from <your-wallet-key-name> \
  -y

# Send the manifest
provider-services send-manifest akash/deploy.yaml \
  --dseq <DSEQ> \
  --provider <PROVIDER_ADDRESS> \
  --from <your-wallet-key-name>

# Check logs
provider-services lease-logs \
  --dseq <DSEQ> \
  --gseq 1 \
  --oseq 1 \
  --provider <PROVIDER_ADDRESS> \
  --from <your-wallet-key-name>
```

### 10.4 Verify secret injection on Akash

```bash
# Shell into the running container
provider-services lease-shell \
  --dseq <DSEQ> \
  --gseq 1 \
  --oseq 1 \
  --provider <PROVIDER_ADDRESS> \
  --from <your-wallet-key-name> \
  -- env | grep -E "OPENAI|SOLANA|HELIUS|VAULT"

# VAULT_ADDR / VAULT_ROLE_ID / VAULT_SECRET_ID should be absent (cleared by entrypoint.sh)
# All agent keys should be populated with real values
```

---

## 11. CI/CD — GitHub Actions

Store the following as GitHub Actions secrets (Settings → Secrets → Actions):

| Secret Name          | Value                                                    |
|----------------------|----------------------------------------------------------|
| `VAULT_ADDR`         | `https://vault.yieldswarm.io:8200`                      |
| `VAULT_ROLE_ID`      | Terraform AppRole role_id from `vault/setup.sh` output   |
| `VAULT_SECRET_ID`    | Terraform AppRole secret_id from `vault/setup.sh` output |

Example workflow (`.github/workflows/terraform.yml`):

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths: ["terraform/**"]

jobs:
  apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Vault CLI
        run: |
          curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor \
            -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
          echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
            https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
            | sudo tee /etc/apt/sources.list.d/hashicorp.list
          sudo apt update && sudo apt install vault jq

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Fetch secrets from Vault and apply
        env:
          VAULT_ADDR:      ${{ secrets.VAULT_ADDR }}
          VAULT_ROLE_ID:   ${{ secrets.VAULT_ROLE_ID }}
          VAULT_SECRET_ID: ${{ secrets.VAULT_SECRET_ID }}
        run: |
          source terraform/scripts/vault-env.sh
          terraform -chdir=terraform init
          terraform -chdir=terraform apply \
            -var="vault_addr=${VAULT_ADDR}" \
            -auto-approve
```

---

## 12. Rotating Secrets

### Rotate an AppRole secret_id

```bash
# Terraform AppRole — generate a new secret_id and update CI secret
NEW_SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/terraform/secret-id)
echo "New VAULT_SECRET_ID: ${NEW_SECRET_ID}"
# → Update GitHub Actions secret VAULT_SECRET_ID with this value

# Akash Agent — generate a wrapped secret_id for next deployment
vault write -wrap-ttl=300s -f auth/approle/role/akash-agent/secret-id
```

### Rotate a KV secret

```bash
# Any vault kv put on an existing path creates a new version (old version preserved)
vault kv put secret/azure/credentials \
  subscription_id="<EXISTING>" \
  client_id="<EXISTING>" \
  client_secret="<NEW_ROTATED_SECRET>" \
  tenant_id="<EXISTING>"

# Verify the new version
vault kv metadata get secret/azure/credentials
vault kv get secret/azure/credentials
```

### Rotate LLM API keys

```bash
vault kv patch secret/agents/master \
  openai_api_key="<NEW_OPENAI_KEY>"
# vault kv patch updates only the specified fields, leaving others unchanged
```

### Emergency: Revoke all Terraform tokens

```bash
# Revokes all tokens issued by the Terraform AppRole — stops terraform immediately
vault token revoke -mode=accessor \
  $(vault list -format=json auth/token/accessors | jq -r '.[]' | \
    xargs -I{} vault token lookup -accessor {} -format=json | \
    jq -r 'select(.data.policies[] == "terraform") | .data.accessor')
```

---

## 13. Disaster Recovery

### Unseal Vault after a restart

You need 3 of the 5 unseal keys generated during `vault operator init`:

```bash
vault operator unseal <KEY_1>
vault operator unseal <KEY_2>
vault operator unseal <KEY_3>
vault status  # sealed: false
```

### Restore from Raft snapshot

```bash
# Create a snapshot (run regularly as a cron)
vault operator raft snapshot save /backup/vault-$(date +%Y%m%d-%H%M%S).snap

# Restore
vault operator raft snapshot restore /backup/vault-20260115-120000.snap
```

### Full Vault loss (worst case)

1. Start a new Vault instance
2. Run `vault operator init` — get new unseal keys and root token
3. Run `bash vault/setup.sh` — recreates policies, AppRole, and secret scaffolding
4. Re-enter all secrets from §6 using your offline backup records
5. Generate new AppRole credentials and update CI secrets and Akash SDL

---

## 14. Security Checklist

Before going to production, verify each item:

- [ ] Vault TLS is enabled with a valid certificate (not self-signed in prod)
- [ ] Vault is not running in dev mode (`vault status` shows `Dev Mode: false`)
- [ ] Unseal keys are stored offline — 5 physical copies, 3-of-5 threshold
- [ ] Root token is revoked after initial setup (`vault token revoke <ROOT_TOKEN>`)
- [ ] All `REPLACE_ME` placeholders have been replaced with real secrets
- [ ] `vault kv get secret/azure/credentials` shows real values (not `REPLACE_ME`)
- [ ] No `.env` file with real secrets exists in the repository
- [ ] Terraform state backend is configured with server-side encryption
- [ ] GitHub Actions secrets are set (VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID)
- [ ] Akash SDL contains no real secrets (only VAULT_ADDR + AppRole credentials)
- [ ] Docker image does not contain secrets (`docker inspect` shows no plaintext keys)
- [ ] `git log -p | grep -E "(sk-|REPLACE_ME|private_key)"` returns nothing sensitive
- [ ] Vault audit log is enabled: `vault audit enable file file_path=/var/log/vault-audit.log`
- [ ] Vault access policies reviewed — least-privilege confirmed for each role
- [ ] AppRole secret_ids have appropriate TTLs for your rotation schedule
- [ ] Monitoring / alerting set up for Vault seal events and auth failures

### Enable Vault audit log

```bash
vault audit enable file file_path=/var/log/vault-audit.log
vault audit list
```

All Vault access (reads, writes, logins) is now logged to `/var/log/vault-audit.log`.
Forward this log to your SIEM or monitoring stack.

---

*For questions or issues, open a GitHub issue or check the [HashiCorp Vault documentation](https://developer.hashicorp.com/vault/docs).*

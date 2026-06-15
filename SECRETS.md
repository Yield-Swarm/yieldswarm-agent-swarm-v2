# YieldSwarm AgentSwarm OS — Secrets Management Guide

This document is the authoritative runbook for provisioning HashiCorp Vault, seeding secrets, wiring Terraform, and deploying Akash workloads with **runtime-only** secret injection. No API keys, tokens, or mnemonics belong in git, Docker images, or SDL files.

## Architecture

```
┌─────────────────┐     AppRole      ┌──────────────────┐
│  HashiCorp Vault │◄────────────────│  Terraform CI    │
│  (KV v2)         │     (read)       │  azure/runpod/   │
└────────┬────────┘                  │  vultr/do/rpc    │
         │                           └──────────────────┘
         │ AppRole (akash-runtime)
         ▼
┌─────────────────┐     deploy.sh    ┌──────────────────┐
│  Akash Lease    │◄─────────────────│  Operator        │
│  (SDL + env)    │  single-use      │  (akash-deploy)  │
└────────┬────────┘  secret-id       └──────────────────┘
         │
         ▼ entrypoint.sh → vault-fetch.sh
┌─────────────────┐
│  Agent Container │  secrets.env → process env
└─────────────────┘
```

### Secret paths (KV v2 mount: `secret/`)

| Path | Contents | Consumers |
|------|----------|-----------|
| `yieldswarm/azure/credentials` | `client_id`, `client_secret`, `subscription_id`, `tenant_id` | Terraform `azurerm` |
| `yieldswarm/runpod/api` | `api_key` | Terraform RunPod |
| `yieldswarm/vultr/api` | `api_key` | Terraform Vultr |
| `yieldswarm/digitalocean/api` | `api_token` | Terraform DO |
| `yieldswarm/rpc/solana` | `primary_url`, `helius_api_key`, `birdeye_api_key` | Terraform, agents |
| `yieldswarm/rpc/failover` | `endpoints` (JSON array) | Terraform, agents |
| `yieldswarm/akash/runtime` | `wallet_mnemonic`, `chain_id`, `node`, `keyring_backend` | Akash containers |
| `yieldswarm/akash/deploy` | `certificate`, `key` | `akash/deploy.sh` only |
| `yieldswarm/agents/shared` | `agentswarm_master_key`, LLM keys, `gpu_cluster_keys` | All agents |

### Policies & AppRoles

| Policy | AppRole | Purpose |
|--------|---------|---------|
| `terraform` | `terraform` | CI/CD read access to cloud + RPC secrets |
| `akash-runtime` | `akash-runtime` | Container runtime (single-use secret-id) |
| `akash-deploy` | `akash-deploy` | SDL deployment + secret-id generation |
| `admin` | (OIDC/group-bound) | Break-glass administration |

---

## Prerequisites

- HashiCorp Vault 1.15+ (HA Raft cluster recommended)
- TLS certificates for Vault (`vault/config/vault.hcl`)
- Auto-unseal configured (AWS KMS, Azure Key Vault, or HSM)
- `vault` CLI, `jq`, `curl`, `terraform` >= 1.6
- `akash` CLI for deployments
- Docker for building the runtime image

---

## Step 1 — Install and initialize Vault

```bash
# Install Vault (Ubuntu/Debian)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y vault

# Copy and edit server config
sudo mkdir -p /etc/vault.d/tls /var/lib/vault/data
sudo cp vault/config/vault.hcl /etc/vault.d/vault.hcl
# Place TLS cert/key at paths referenced in vault.hcl

sudo systemctl enable --now vault
```

Initialize and unseal (first node only):

```bash
export VAULT_ADDR='https://vault.yieldswarm.internal:8200'

vault operator init -key-shares=5 -key-threshold=3 -format=json | tee vault-init.json
# Store unseal keys and root token in separate secure locations (Shamir shards)

vault operator unseal   # repeat until sealed=false (3 of 5 keys)
export VAULT_TOKEN='<root-token-from-init>'
```

Enable audit logging (required for production):

```bash
sudo mkdir -p /var/log/vault
vault audit enable file file_path=/var/log/vault/audit.log
```

---

## Step 2 — Bootstrap policies, engines, and AppRoles

```bash
export VAULT_ADDR='https://vault.yieldswarm.internal:8200'
export VAULT_TOKEN='<bootstrap-admin-token>'

chmod +x vault/scripts/*.sh
./vault/scripts/bootstrap.sh
```

This runs:
1. `setup-secrets-engines.sh` — enables KV v2 at `secret/`, creates path placeholders
2. `setup-policies.sh` — writes policies from `vault/policies/*.hcl`
3. `create-approles.sh` — creates `terraform`, `akash-runtime`, `akash-deploy` roles

Save the printed role IDs:

```bash
export TF_ROLE_ID=$(vault read -field=role_id auth/approle/role/terraform/role-id)
export AKASH_RUNTIME_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
export AKASH_DEPLOY_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-deploy/role-id)
```

---

## Step 3 — Seed production secrets

Export real values in your shell (never commit these), then run:

```bash
export VAULT_ADDR='https://vault.yieldswarm.internal:8200'
export VAULT_TOKEN='<admin-token>'

# Azure
export AZURE_CLIENT_ID='...'
export AZURE_CLIENT_SECRET='...'
export AZURE_SUBSCRIPTION_ID='...'
export AZURE_TENANT_ID='...'

# Cloud providers
export RUNPOD_API_KEY='...'
export VULTR_API_KEY='...'
export DO_API_TOKEN='...'

# RPC
export SOLANA_RPC_URL='https://mainnet.helius-rpc.com/?api-key=...'
export HELIUS_API_KEY='...'
export BIRDEYE_API_KEY='...'
export FAILOVER_RPC_LIST='["https://api.mainnet-beta.solana.com","https://rpc.ankr.com/solana"]'

# Akash
export AKASH_WALLET_MNEMONIC='word1 word2 ...'
export AKASH_KEYRING_BACKEND='file'
export AKASH_CHAIN_ID='akashnet-2'
export AKASH_NODE='https://rpc.akash.forbole.com:443'
export AKASH_CERTIFICATE="$(cat ~/.akash/cert.pem)"
export AKASH_KEY="$(cat ~/.akash/key.pem)"

# Agents
export AGENTSWARM_MASTER_KEY='...'
export OPENAI_API_KEY='...'
export GROK_API_KEY='...'
export GPU_CLUSTER_KEYS='["runpod_key1"]'

./vault/scripts/seed-secrets.sh
```

Verify:

```bash
vault kv list secret/yieldswarm/
vault kv get secret/yieldswarm/azure/credentials  # confirm keys exist (values redacted in logs)
```

Revoke the bootstrap root token after seeding:

```bash
vault token revoke <root-token>
```

---

## Step 4 — Configure Terraform to pull secrets from Vault

Generate a Terraform AppRole secret-id:

```bash
export VAULT_ADDR='https://vault.yieldswarm.internal:8200'
vault login -method=approle role_id="$TF_ROLE_ID" secret_id="$(vault write -f -field=secret_id auth/approle/role/terraform/secret-id)"

export TF_VAR_vault_addr='https://vault.yieldswarm.internal:8200'
export TF_VAR_vault_role_id="$TF_ROLE_ID"
export TF_VAR_vault_secret_id="$(vault write -f -field=secret_id auth/approle/role/terraform/secret-id)"
```

Initialize and plan:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars for non-secret values (region, environment)

terraform init
terraform plan
terraform apply
```

Terraform reads all provider credentials from Vault data sources in `terraform/vault.tf`:

- **Azure** → `data.vault_kv_secret_v2.azure` → `provider "azurerm"`
- **RunPod** → `data.vault_kv_secret_v2.runpod` → `provider "runpod"`
- **Vultr** → `data.vault_kv_secret_v2.vultr` → `provider "vultr"`
- **DigitalOcean** → `data.vault_kv_secret_v2.digitalocean` → `provider "digitalocean"`
- **RPC** → `data.vault_kv_secret_v2.rpc_*` → outputs + Azure Key Vault mirror

### CI/CD integration (GitHub Actions example)

Store in your CI secret store (not in repo):

```
VAULT_ADDR
TF_VAR_vault_role_id
TF_VAR_vault_secret_id   # rotate per pipeline run
```

```yaml
# .github/workflows/terraform.yml (reference — do not commit secret values)
- name: Terraform Apply
  env:
    VAULT_ADDR: ${{ secrets.VAULT_ADDR }}
    TF_VAR_vault_addr: ${{ secrets.VAULT_ADDR }}
    TF_VAR_vault_role_id: ${{ secrets.TF_VAULT_ROLE_ID }}
    TF_VAR_vault_secret_id: ${{ secrets.TF_VAULT_SECRET_ID }}
  run: |
    cd terraform
    terraform init
    terraform apply -auto-approve
```

---

## Step 5 — Build and push the Docker image

The image contains **zero secrets**. Verify before pushing:

```bash
docker build -f docker/Dockerfile -t ghcr.io/yieldswarm/agentswarm:latest .

# Confirm no secrets in image layers
docker run --rm ghcr.io/yieldswarm/agentswarm:latest env | grep -iE 'key|token|secret|mnemonic' && echo "FAIL" || echo "PASS"
```

Push:

```bash
docker push ghcr.io/yieldswarm/agentswarm:latest
```

---

## Step 6 — Deploy to Akash with runtime secret injection

### 6a. Authenticate as akash-deploy

```bash
export VAULT_ADDR='https://vault.yieldswarm.internal:8200'
export VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="$AKASH_DEPLOY_ROLE_ID" \
  secret_id="$(vault write -f -field=secret_id auth/approle/role/akash-deploy/secret-id)")
```

### 6b. Set Akash wallet context

```bash
export AKASH_FROM='akash1...'
export AKASH_KEYRING_BACKEND='file'
export AKASH_CHAIN_ID='akashnet-2'
export AKASH_NODE='https://rpc.akash.forbole.com:443'
export DEPLOY_SIGNED_BY='akash1...'   # provider attribute in SDL
```

### 6c. Deploy

```bash
chmod +x akash/deploy.sh
./akash/deploy.sh
```

What happens:
1. `deploy.sh` reads SDL signing cert/key from `secret/yieldswarm/akash/deploy`
2. Generates a **single-use** `akash-runtime` secret-id
3. Passes `VAULT_ROLE_ID` + `VAULT_SECRET_ID` as deployment env vars (never in SDL file)
4. Container starts → `entrypoint.sh` → `vault-fetch.sh` → secrets loaded → agent runs

### 6d. Verify runtime injection

```bash
# Find your lease
akash query deployment list --owner "$AKASH_FROM" --node "$AKASH_NODE"

# Check logs (should show "Secrets loaded", never print values)
akash provider lease-logs --dseq <DSEQ> --gseq 1 --oseq 1 --provider <PROVIDER>
```

---

## Step 7 — Local development (dev Vault only)

For local testing with a dev Vault server:

```bash
vault server -dev -dev-root-token-id=dev-only-token &
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='dev-only-token'
export VAULT_SKIP_VERIFY=true

./vault/scripts/bootstrap.sh
# Seed with test values (use dummy credentials)
VAULT_SKIP_VERIFY=true ./vault/scripts/seed-secrets.sh

docker run --rm \
  -e VAULT_ADDR=http://host.docker.internal:8200 \
  -e VAULT_ROLE_ID="$AKASH_RUNTIME_ROLE_ID" \
  -e VAULT_SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)" \
  -e VAULT_SKIP_VERIFY=true \
  ghcr.io/yieldswarm/agentswarm:latest
```

Never use `-dev` mode or `VAULT_SKIP_VERIFY` in production.

---

## Rotation procedures

### Rotate a cloud API key

```bash
vault kv patch secret/yieldswarm/runpod/api api_key="new-key"
# Re-run terraform apply or restart affected workloads
```

### Rotate Akash runtime credentials

```bash
# 1. Update secret
vault kv patch secret/yieldswarm/akash/runtime wallet_mnemonic="new words..."

# 2. Redeploy with fresh single-use secret-id
./akash/deploy.sh
```

### Rotate AppRole secret-ids

```bash
# Terraform — generate new secret-id for CI
vault write -f auth/approle/role/terraform/secret-id

# Akash runtime — always single-use, generated per deployment
vault write -f auth/approle/role/akash-runtime/secret-id
```

### Emergency revocation

```bash
vault token revoke -accessor <accessor>
vault write auth/approle/role/akash-runtime/secret-id/accessor/<accessor> revoke=true
```

---

## Security checklist

- [ ] Vault runs with TLS and audit logging enabled
- [ ] Auto-unseal configured (no manual unseal in production)
- [ ] Root token revoked after bootstrap
- [ ] AppRoles use least-privilege policies
- [ ] `akash-runtime` secret-ids are single-use (`secret_id_num_uses=1`)
- [ ] No secrets in git, Docker images, SDL, or Terraform `.tfvars`
- [ ] `.env` files are gitignored; use Vault as source of truth
- [ ] CI secret-ids rotated per pipeline run
- [ ] Network policy: only agent subnets can reach `VAULT_ADDR`

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `AppRole login failed` | Check `VAULT_ROLE_ID` / `VAULT_SECRET_ID`; secret-id may be consumed or expired |
| `Required secret SOLANA_RPC_URL not found` | Verify `secret/yieldswarm/rpc/solana` has `primary_url` key |
| `permission denied` on kv get | Confirm policy is attached to the AppRole |
| Terraform `vault` provider auth error | Set `TF_VAR_vault_role_id` and `TF_VAR_vault_secret_id` |
| Akash deploy fails on cert | Check `secret/yieldswarm/akash/deploy` certificate/key PEM format |

---

## File reference

```
vault/
  config/vault.hcl          # Production server config template
  policies/                 # HCL policies (terraform, akash-runtime, akash-deploy, admin)
  scripts/
    bootstrap.sh            # Master setup
    setup-secrets-engines.sh
    setup-policies.sh
    create-approles.sh
    seed-secrets.sh         # Interactive secret seeding
terraform/
  vault.tf                  # Vault data sources → all provider creds
  azure.tf / runpod.tf / vultr.tf / digitalocean.tf / rpc.tf
docker/
  Dockerfile                # No secrets baked in
  entrypoint.sh             # Runtime injection orchestrator
  vault-fetch.sh            # AppRole login + KV fetch
akash/
  deploy.yaml               # SDL (no secret values)
  deploy.sh                 # Vault-aware deployment script
lib/secrets.py              # Runtime env validation (no Vault client in Python)
```
